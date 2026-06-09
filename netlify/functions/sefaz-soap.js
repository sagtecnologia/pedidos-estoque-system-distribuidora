const https = require('https');

const json = (statusCode, body) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(body),
});

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return json(405, { erro: 'Metodo nao permitido' });
  }

  const expectedSecret = process.env.SEFAZ_SOAP_PROXY_SECRET || '';
  const receivedSecret = event.headers['x-sefaz-proxy-secret'] || event.headers['X-Sefaz-Proxy-Secret'] || '';
  if (!expectedSecret || receivedSecret !== expectedSecret) {
    return json(401, { erro: 'Proxy SEFAZ nao autorizado' });
  }

  let payload;
  try {
    payload = JSON.parse(event.body || '{}');
  } catch (error) {
    return json(400, { erro: 'JSON invalido' });
  }

  const { url, body, headers, certChainPem, privateKeyPem } = payload;
  if (!url || !body || !certChainPem || !privateKeyPem) {
    return json(400, { erro: 'url, body, certChainPem e privateKeyPem sao obrigatorios' });
  }

  try {
    const resposta = await enviarSoapSefaz({
      url,
      body,
      headers: headers || {},
      certChainPem,
      privateKeyPem,
    });

    return json(200, resposta);
  } catch (error) {
    return json(502, {
      erro: error instanceof Error ? error.message : String(error),
    });
  }
};

async function enviarSoapSefaz(params) {
  try {
    return await enviarSoapSefazTentativa({
      ...params,
      rejectUnauthorized: true,
    });
  } catch (error) {
    if (!deveTentarSemVerificarPeer(error)) {
      throw error;
    }

    const resposta = await enviarSoapSefazTentativa({
      ...params,
      rejectUnauthorized: false,
    });
    return {
      ...resposta,
      ssl_verify_fallback: true,
    };
  }
}

function enviarSoapSefazTentativa({ url, body, headers, certChainPem, privateKeyPem, rejectUnauthorized }) {
  return new Promise((resolve, reject) => {
    const destino = new URL(url);
    const bodyBuffer = Buffer.from(body, 'utf8');

    const req = https.request({
      hostname: destino.hostname,
      port: destino.port || 443,
      path: `${destino.pathname || '/'}${destino.search || ''}`,
      method: 'POST',
      cert: certChainPem,
      key: privateKeyPem,
      rejectUnauthorized,
      minVersion: 'TLSv1.2',
      maxVersion: 'TLSv1.3',
      headers: {
        ...headers,
        Host: destino.hostname,
        Expect: '',
        'Content-Length': bodyBuffer.length,
      },
      timeout: 60000,
    }, (res) => {
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => {
        resolve({
          status: res.statusCode || 0,
          headers: res.headers || {},
          body: Buffer.concat(chunks).toString('utf8'),
          ssl_peer_verified: rejectUnauthorized,
        });
      });
    });

    req.on('timeout', () => {
      req.destroy(new Error('Timeout ao conectar na SEFAZ'));
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.write(bodyBuffer);
    req.end();
  });
}

function deveTentarSemVerificarPeer(error) {
  const code = String(error?.code || '');
  const message = String(error?.message || '');
  return [
    'UNABLE_TO_GET_ISSUER_CERT',
    'UNABLE_TO_GET_ISSUER_CERT_LOCALLY',
    'UNABLE_TO_VERIFY_LEAF_SIGNATURE',
    'SELF_SIGNED_CERT_IN_CHAIN',
    'DEPTH_ZERO_SELF_SIGNED_CERT',
  ].includes(code)
    || /unable to get local issuer certificate|unable to verify|self signed certificate/i.test(message);
}
