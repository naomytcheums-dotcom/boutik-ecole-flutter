// Pont WebRTC des salons vocaux (« Live Étude ») : son (micro + écoute) et partage d'écran directement entre les appareils des membres.
// La signalisation (offres, réponses, candidats ICE) passe par Supabase Realtime côté Dart ; ce fichier ne parle à aucun serveur.
// Négociation « parfaite » : chaque paire de personnes se connecte seule, sans coordinateur ; la personne dont l'identifiant est le plus petit cède en cas de collision.
(function () {
  var ICE = { iceServers: [{ urls: 'stun:stun.l.google.com:19302' }, { urls: 'stun:stun1.l.google.com:19302' }] };
  var self = null, send = null, cb = null, mic = null, screen = null, peers = {}, overlay = null, overlayVideo = null, started = false;

  function supported() {
    return !!(window.RTCPeerConnection && navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
  }
  function canShareScreen() {
    return !!(navigator.mediaDevices && navigator.mediaDevices.getDisplayMedia);
  }
  function notify(kind, value) {
    try { if (cb && cb[kind]) cb[kind](value); } catch (e) { /* le rappel Dart a pu être détruit */ }
  }

  function ensureOverlay() {
    if (overlay) return;
    overlay = document.createElement('div');
    overlay.id = 'boutik-room-screen';
    overlay.style.cssText = 'position:fixed;left:8px;right:8px;top:64px;max-height:46vh;z-index:2147483000;background:#000;border-radius:12px;overflow:hidden;display:none;box-shadow:0 8px 28px rgba(0,0,0,.35)';
    overlayVideo = document.createElement('video');
    overlayVideo.autoplay = true;
    overlayVideo.playsInline = true;
    overlayVideo.muted = true; // le son passe par les éléments audio ; la vidéo d'écran reste muette
    overlayVideo.style.cssText = 'width:100%;max-height:46vh;object-fit:contain;background:#000';
    overlay.appendChild(overlayVideo);
    document.body.appendChild(overlay);
  }
  function showScreen(stream, who) {
    ensureOverlay();
    overlayVideo.srcObject = stream;
    overlay.style.display = 'block';
    overlay.setAttribute('data-from', who);
    notify('remoteScreen', who);
  }
  function hideScreen(who) {
    if (!overlay || overlay.getAttribute('data-from') !== who) return;
    overlay.style.display = 'none';
    overlayVideo.srcObject = null;
    notify('remoteScreen', '');
  }

  function peer(id) {
    if (peers[id]) return peers[id];
    var pc = new RTCPeerConnection(ICE);
    var p = { pc: pc, makingOffer: false, ignoreOffer: false, audio: null, senders: [] };
    peers[id] = p;
    if (mic) mic.getTracks().forEach(function (t) { pc.addTrack(t, mic); });
    if (screen) screen.getTracks().forEach(function (t) { p.senders.push(pc.addTrack(t, screen)); });
    pc.onicecandidate = function (e) { if (e.candidate) send(id, JSON.stringify({ c: e.candidate })); };
    pc.ontrack = function (e) {
      var st = e.streams && e.streams[0] ? e.streams[0] : new MediaStream([e.track]);
      if (e.track.kind === 'audio') {
        if (!p.audio) {
          p.audio = document.createElement('audio');
          p.audio.autoplay = true;
          p.audio.style.display = 'none';
          document.body.appendChild(p.audio);
        }
        p.audio.srcObject = st;
        var play = p.audio.play();
        if (play && play.catch) play.catch(function () { notify('error', 'autoplay_blocked'); });
      } else {
        showScreen(st, id);
        e.track.onmute = function () { hideScreen(id); };
        e.track.onended = function () { hideScreen(id); };
        e.track.onunmute = function () { showScreen(st, id); };
      }
    };
    pc.onnegotiationneeded = function () {
      p.makingOffer = true;
      pc.setLocalDescription().then(function () {
        send(id, JSON.stringify({ d: pc.localDescription }));
      }).catch(function () { /* renégociation ignorée : la suivante réessaiera */ }).then(function () { p.makingOffer = false; });
    };
    pc.onconnectionstatechange = function () { notify('peer', id + ':' + pc.connectionState); };
    return p;
  }

  async function start(selfId, sendSignal, callbacks) {
    self = selfId; send = sendSignal; cb = callbacks;
    if (!supported()) { notify('error', 'unsupported'); throw new Error('unsupported'); }
    try {
      mic = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true }, video: false });
    } catch (e) {
      notify('error', e && e.name === 'NotAllowedError' ? 'permission_denied' : (e && e.name === 'NotFoundError' ? 'device_not_found' : 'device_busy'));
      throw e;
    }
    started = true;
  }

  function peerJoined(id) { if (started) peer(id); }

  function peerLeft(id) {
    var p = peers[id];
    if (!p) return;
    try { p.pc.close(); } catch (e) { /* déjà fermée */ }
    if (p.audio) { p.audio.srcObject = null; p.audio.remove(); }
    hideScreen(id);
    delete peers[id];
  }

  async function signal(from, json) {
    if (!started) return;
    var m = JSON.parse(json);
    var p = peer(from), pc = p.pc, polite = self < from;
    if (m.d) {
      var collision = m.d.type === 'offer' && (p.makingOffer || pc.signalingState !== 'stable');
      p.ignoreOffer = !polite && collision;
      if (p.ignoreOffer) return;
      await pc.setRemoteDescription(m.d);
      if (m.d.type === 'offer') {
        await pc.setLocalDescription();
        send(from, JSON.stringify({ d: pc.localDescription }));
      }
    } else if (m.c) {
      try { await pc.addIceCandidate(m.c); } catch (e) { if (!p.ignoreOffer) throw e; }
    }
  }

  function setMic(on) {
    if (mic) mic.getAudioTracks().forEach(function (t) { t.enabled = !!on; });
  }

  async function startScreen() {
    if (!canShareScreen()) { notify('error', 'screen_unsupported'); return false; }
    try {
      screen = await navigator.mediaDevices.getDisplayMedia({ video: true, audio: false });
    } catch (e) { return false; }
    var track = screen.getVideoTracks()[0];
    track.onended = function () { stopScreen(); notify('screenEnded', ''); };
    Object.keys(peers).forEach(function (id) {
      var p = peers[id];
      p.senders.push(p.pc.addTrack(track, screen));
    });
    return true;
  }

  function stopScreen() {
    if (!screen) return;
    screen.getTracks().forEach(function (t) { t.onended = null; t.stop(); });
    Object.keys(peers).forEach(function (id) {
      var p = peers[id];
      p.senders.forEach(function (s) { try { p.pc.removeTrack(s); } catch (e) { /* connexion fermée */ } });
      p.senders = [];
    });
    screen = null;
  }

  function leave() {
    stopScreen();
    Object.keys(peers).forEach(peerLeft);
    if (mic) { mic.getTracks().forEach(function (t) { t.stop(); }); mic = null; }
    if (overlay) { overlay.remove(); overlay = null; overlayVideo = null; }
    started = false; cb = null; send = null;
  }

  window.boutikRoom = { supported: supported, canShareScreen: canShareScreen, start: start, peerJoined: peerJoined, peerLeft: peerLeft, signal: signal, setMic: setMic, startScreen: startScreen, stopScreen: stopScreen, leave: leave };
})();
