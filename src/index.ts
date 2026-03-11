interface Env {
    ascendii_db: any;
    ascendii_kv: any;
}

export default { fetch: (request: Request, env: Env) => {
    return new Response('Ascendii Worker is Live!');
}};