// Faux « @supabase/supabase-js » pour les tests de contrat des Edge Functions : aucun réseau. L'état est partagé par globalThis.__CONTRACT__ (voir register.mjs).
const W = () => globalThis.__CONTRACT__;

function builder(table) {
  const op = { table, kind: 'select', filters: [] };
  W().dbCalls.push(op);
  const b = new Proxy({}, {
    get(_t, prop) {
      if (prop === 'then') return (res, rej) => Promise.resolve(W().tableResult(op)).then(res, rej);
      if (['insert', 'update', 'delete', 'upsert'].includes(prop)) return (...a) => { op.kind = prop; op.payload = a[0]; return b; };
      return (...a) => { op.filters.push([prop, ...a]); return b; };
    },
  });
  return b;
}

export function createClient(url, key, opts = {}) {
  const header = opts?.global?.headers?.Authorization ?? '';
  return {
    auth: {
      getUser: async () => {
        W().authCalls.push(header);
        const token = /^Bearer\s+(.+)$/i.exec(header)?.[1];
        const id = token ? W().tokens.get(token) ?? null : null;
        return { data: { user: id ? { id, email: 'contrat@example.test' } : null }, error: id ? null : { message: 'invalid JWT' } };
      },
    },
    from: (table) => builder(table),
    rpc: async (fn, args) => {
      W().rpcCalls.push({ fn, args });
      return W().rpcResult(fn, args);
    },
    storage: { from: () => { throw new Error('storage non simulé'); } },
  };
}
export const SupabaseClient = class {};
