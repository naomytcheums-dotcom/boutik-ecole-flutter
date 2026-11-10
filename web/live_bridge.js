/* Pont entre l'application (Dart) et le SDK LiveKit pour navigateur.
 * Charge le SDK à la demande (une seule fois), se connecte à la salle avec le jeton émis par l'Edge Function « live-token »,
 * publie caméra/micro pour l'hôte, affiche la vidéo de l'hôte pour les spectateurs. Aucune clé n'est présente ici.
 * Version du SDK figée (livekit-client 2.22.3). */
(function () {
  var SDK = 'https://cdn.jsdelivr.net/npm/livekit-client@2.22.3/dist/livekit-client.umd.min.js';
  var loading = null;
  function loadSdk() {
    if (window.LivekitClient) return Promise.resolve();
    if (loading) return loading;
    loading = new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = SDK;
      s.async = true;
      s.onload = function () { window.LivekitClient ? resolve() : reject(new Error('sdk_unavailable')); };
      s.onerror = function () { loading = null; reject(new Error('sdk_unavailable')); };
      document.head.appendChild(s);
    });
    return loading;
  }
  function describe(e) {
    var n = (e && (e.name || '')) + ' ' + (e && (e.message || e) || '');
    if (/NotAllowed|Permission/i.test(n)) return 'permission_denied';
    if (/NotFound|DevicesNotFound/i.test(n)) return 'device_not_found';
    if (/NotReadable|TrackStart/i.test(n)) return 'device_busy';
    if (/sdk_unavailable/.test(n)) return 'sdk_unavailable';
    return 'connect_failed';
  }
  var session = null;
  window.boutikLive = {
    supported: function () { return !!(navigator.mediaDevices && window.isSecureContext !== false); },
    /* cb : { state(s), participants(n), error(code) } ; s : connecting | connected | reconnecting | disconnected */
    connect: function (url, token, publish, elementId, cb) {
      return loadSdk().then(function () {
        var L = window.LivekitClient;
        var room = new L.Room({ adaptiveStream: true, dynacast: true, reconnectPolicy: undefined });
        var el = document.getElementById(elementId);
        function clear() { if (el) el.innerHTML = ''; }
        // Plusieurs diffuseurs (hôte + invités) : leurs vidéos se partagent l'écran en grille.
        var vids = {};
        function relayout() {
          var keys = Object.keys(vids), n = keys.length;
          if (!el) return;
          el.style.display = 'flex'; el.style.flexWrap = 'wrap';
          keys.forEach(function (k) {
            vids[k].style.cssText = 'background:#000;object-fit:' + (n > 1 ? 'cover' : 'contain') + ';width:' + (n > 1 ? '50%' : '100%') + ';height:' + (n > 2 ? '50%' : '100%');
          });
        }
        function attach(track) {
          if (!el || track.kind !== 'video') return;
          if (vids[track.sid]) return;
          var v = track.attach();
          v.setAttribute('playsinline', ''); v.muted = !publish ? false : true;
          vids[track.sid] = v;
          el.appendChild(v);
          relayout();
        }
        room.on(L.RoomEvent.TrackUnsubscribed, function (track) {
          var v = vids[track.sid];
          if (v) { try { track.detach(v); } catch (e) {} if (v.parentNode) v.parentNode.removeChild(v); delete vids[track.sid]; relayout(); }
        });
        function count() { cb.participants(Math.max(0, room.numParticipants - (publish ? 0 : 0))); }
        room.on(L.RoomEvent.TrackSubscribed, function (track) { attach(track); if (track.kind === 'audio' && el) { var a = track.attach(); el.appendChild(a); } });
        room.on(L.RoomEvent.TrackUnsubscribed, function (track) { track.detach(); if (track.kind === 'video') clear(); });
        room.on(L.RoomEvent.ParticipantConnected, count);
        room.on(L.RoomEvent.ParticipantDisconnected, count);
        room.on(L.RoomEvent.Reconnecting, function () { cb.state('reconnecting'); });
        room.on(L.RoomEvent.Reconnected, function () { cb.state('connected'); });
        room.on(L.RoomEvent.Disconnected, function () { cb.state('disconnected'); });
        room.on(L.RoomEvent.MediaDevicesError, function (e) { cb.error(describe(e)); });
        cb.state('connecting');
        return room.connect(url, token).then(function () {
          session = room;
          cb.state('connected');
          count();
          if (publish) {
            return room.localParticipant.setCameraEnabled(true).then(function () {
              return room.localParticipant.setMicrophoneEnabled(true).catch(function (e) { cb.error(describe(e)); });
            }).then(function () {
              var pub = room.localParticipant.getTrackPublication(L.Track.Source.Camera);
              if (pub && pub.track) attach(pub.track);
            });
          } else {
            room.remoteParticipants.forEach(function (p) {
              p.trackPublications.forEach(function (pub) { if (pub.track) { attach(pub.track); if (pub.track.kind === 'audio' && el) el.appendChild(pub.track.attach()); } });
            });
          }
        });
      }).catch(function (e) { cb.error(describe(e)); throw e; });
    },
    setCamera: function (on) { return session ? session.localParticipant.setCameraEnabled(on) : Promise.resolve(); },
    setMic: function (on) { return session ? session.localParticipant.setMicrophoneEnabled(on) : Promise.resolve(); },
    disconnect: function () {
      var r = session; session = null;
      return r ? r.disconnect() : Promise.resolve();
    }
  };
})();
