import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create } from "npm:xmlbuilder2@3.1.1";
import { XMLParser } from "npm:fast-xml-parser@4.5.0";
import { SignedXml } from "npm:xml-crypto@6.0.1";
import forge from "npm:node-forge@1.3.1";

const NFE_NS = "http://www.portalfiscal.inf.br/nfe";
const SOAP_NS = "http://www.w3.org/2003/05/soap-envelope";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_",
  trimValues: true,
});

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const action = body?.action;

    if (!action) {
      throw new Error("AÃƒÂ§ÃƒÂ£o nÃƒÂ£o informada");
    }

    if (action === "validar_certificado") {
      const certificado = body?.certificado;
      const senha = body?.senha;

      if (!certificado || !senha) {
        throw new Error("Certificado e senha sÃƒÂ£o obrigatÃƒÂ³rios");
      }

      const material = parsePfx(certificado, senha);
      return jsonResponse({
        success: true,
        validade: material.validToIsoDate,
        subject: material.subject,
        issuer: material.issuer,
        serial_number: material.serialNumber,
        chain_length: material.chainLength,
        tls_chain_length: material.tlsChainLength,
        tls_chain_complete: material.tlsChainComplete,
      });
    }

    const empresa = await carregarEmpresa();
    const ambiente = normalizarAmbiente(body?.ambiente ?? empresa.focusnfe_ambiente ?? empresa.nuvemfiscal_ambiente);
    const uf = String(body?.uf || empresa.estado || "").toUpperCase();
    const sefaz = resolverSefaz(uf, ambiente);
    const certificado = parsePfx(empresa.certificado_digital, empresa.senha_certificado);

    switch (action) {
      case "status":
        return jsonResponse(await consultarStatusSefaz({
          sefaz,
          ambiente,
          uf,
          certificado,
        }));
      case "emitir":
        return jsonResponse(await emitirNfce({
          sefaz,
          ambiente,
          uf,
          certificado,
          empresa,
          payload: body?.payload,
        }));
      case "consultar":
        return jsonResponse(await consultarNfce({
          sefaz,
          ambiente,
          uf,
          certificado,
          chaveAcesso: normalizarChaveAcesso(body?.chave_acesso),
        }));
      case "cancelar":
        return jsonResponse(await cancelarNfce({
          sefaz,
          ambiente,
          uf,
          certificado,
          chaveAcesso: normalizarChaveAcesso(body?.chave_acesso),
          justificativa: body?.justificativa,
          protocoloAutorizacao: body?.protocolo_autorizacao,
        }));
      default:
        throw new Error(`AÃƒÂ§ÃƒÂ£o nÃƒÂ£o suportada: ${action}`);
    }
  } catch (error) {
    console.error("[sefaz-nfce] erro:", error);
    return jsonResponse(
      { erro: error instanceof Error ? error.message : "Erro interno da funÃƒÂ§ÃƒÂ£o" },
      500,
    );
  }
});

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

async function carregarEmpresa() {
  const { data, error } = await supabase
    .from("empresa_config")
    .select("*")
    .limit(1)
    .maybeSingle();

  if (error || !data) {
    throw new Error("ConfiguraÃƒÂ§ÃƒÂ£o da empresa nÃƒÂ£o encontrada");
  }

  if (!data.certificado_digital || !data.senha_certificado) {
    throw new Error("Certificado digital A1 nÃƒÂ£o configurado");
  }

  if (!data.csc_id || !data.csc_token) {
    throw new Error("CSC ID e CSC Token nÃƒÂ£o configurados");
  }

  return data;
}

function normalizarAmbiente(ambiente: unknown) {
  return parseInt(String(ambiente || 2), 10) === 1 ? 1 : 2;
}

function normalizarChaveAcesso(chave: unknown) {
  const somenteDigitos = String(chave || "").replace(/\D/g, "");
  if (somenteDigitos && somenteDigitos.length !== 44) {
    throw new Error(`Chave de acesso invalida: esperado 44 digitos, recebido ${somenteDigitos.length}`);
  }
  return somenteDigitos;
}

function resolverSefaz(uf: string, ambiente: number) {
  if (uf !== "GO") {
    throw new Error(`SEFAZ direta ainda nÃƒÂ£o estÃƒÂ¡ mapeada para a UF ${uf}. Esta implementaÃƒÂ§ÃƒÂ£o cobre GoiÃƒÂ¡s.`);
  }

  const base = ambiente === 1
    ? "https://nfe.sefaz.go.gov.br/nfe/services"
    : "https://homolog.sefaz.go.gov.br/nfe/services";

  return {
    autorizacao: `${base}/NFeAutorizacao4?`,
    consultaProtocolo: `${base}/NFeConsultaProtocolo4?`,
    statusServico: `${base}/NFeStatusServico4?`,
    recepcaoEvento: `${base}/NFeRecepcaoEvento4?`,
    qrCodeUrl: ambiente === 1
      ? "https://nfeweb.sefaz.go.gov.br/nfeweb/sites/nfce/danfeNFCe"
      : "https://nfewebhomolog.sefaz.go.gov.br/nfeweb/sites/nfce/danfeNFCe",
    urlChave: ambiente === 1
      ? "www.sefaz.go.gov.br/nfce/consulta"
      : "www.sefaz.go.gov.br/nfce/consulta",
  };
}

function parsePfx(base64: string, password: string) {
  const p12Der = forge.util.decode64(
    String(base64 || "")
      .replace(/^data:.*;base64,/, "")
      .replace(/\s+/g, ""),
  );
  const p12Asn1 = forge.asn1.fromDer(p12Der);
  const p12 = forge.pkcs12.pkcs12FromAsn1(p12Asn1, false, password);

  const pkcs8KeyBags = p12.getBags({
    bagType: forge.pki.oids.pkcs8ShroudedKeyBag,
  })[forge.pki.oids.pkcs8ShroudedKeyBag] || [];
  const keyBags = p12.getBags({
    bagType: forge.pki.oids.keyBag,
  })[forge.pki.oids.keyBag] || [];

  const certBags = p12.getBags({
    bagType: forge.pki.oids.certBag,
  })[forge.pki.oids.certBag] || [];

  const allKeyBags = [...pkcs8KeyBags, ...keyBags];

  if (!allKeyBags.length || !certBags.length) {
    throw new Error("NÃƒÂ£o foi possÃƒÂ­vel extrair chave privada e certificado do arquivo PFX");
  }

  const keyBag = allKeyBags[0];
  const privateKeyPem = forge.pki.privateKeyToPem(keyBag.key);
  const certs = certBags
    .map((bag: any) => bag.cert)
    .filter(Boolean);
  const cert = selecionarCertificadoTitular(certs, keyBag);
  const cadeia = ordenarCadeiaCertificados(cert, certs);
  const certPem = forge.pki.certificateToPem(cert);
  const certChainPem = cadeia
    .map((item: any) => forge.pki.certificateToPem(item))
    .join("\n");
  const certBase64 = certPem
    .replace("-----BEGIN CERTIFICATE-----", "")
    .replace("-----END CERTIFICATE-----", "")
    .replace(/\r?\n/g, "");

  return {
    privateKeyPem,
    certPem,
    certChainPem,
    certBase64,
    validToIsoDate: cert.validity.notAfter.toISOString().slice(0, 10),
    subject: cert.subject.attributes.map((item: { shortName?: string; name: string; value: string }) => `${item.shortName || item.name}=${item.value}`).join(", "),
    issuer: cert.issuer.attributes.map((item: { shortName?: string; name: string; value: string }) => `${item.shortName || item.name}=${item.value}`).join(", "),
    serialNumber: cert.serialNumber,
    chainLength: cadeia.length,
    tlsChainLength: cadeia.length,
    tlsChainComplete: cadeia.length > 1,
  };
}

function selecionarCertificadoTitular(certs: any[], keyBag: any) {
  const localKeyId = obterLocalKeyId(keyBag);
  if (localKeyId) {
    const certPorLocalKeyId = certs.find((cert: any) => obterLocalKeyId(cert) === localKeyId);
    if (certPorLocalKeyId) {
      return certPorLocalKeyId;
    }
  }

  const certPorChavePublica = certs.find((cert: any) => certificadoCorrespondeAChave(cert, keyBag.key));
  if (certPorChavePublica) {
    return certPorChavePublica;
  }

  return certs[0];
}

function obterLocalKeyId(item: any) {
  const localKeyId = item?.attributes?.localKeyId?.[0];
  if (!localKeyId) {
    return null;
  }

  if (typeof localKeyId === "string") {
    return localKeyId;
  }

  if (Array.isArray(localKeyId)) {
    return localKeyId.join("");
  }

  return String(localKeyId);
}

function certificadoCorrespondeAChave(cert: any, privateKey: any) {
  const certKey = cert?.publicKey;
  if (!certKey?.n || !certKey?.e || !privateKey?.n || !privateKey?.e) {
    return false;
  }

  return certKey.n.compareTo(privateKey.n) === 0 && certKey.e.compareTo(privateKey.e) === 0;
}

function ordenarCadeiaCertificados(certTitular: any, certs: any[]) {
  const cadeia = [certTitular];
  const restantes = certs.filter((cert) => cert !== certTitular);
  let atual = certTitular;

  while (restantes.length) {
    const indiceProximo = restantes.findIndex((cert) => dnIgual(cert.subject, atual.issuer));
    if (indiceProximo === -1) {
      break;
    }

    const [proximo] = restantes.splice(indiceProximo, 1);
    cadeia.push(proximo);

    if (dnIgual(proximo.subject, proximo.issuer)) {
      break;
    }

    atual = proximo;
  }

  return cadeia.concat(restantes);
}

function dnIgual(a: any, b: any) {
  return serializarDn(a) === serializarDn(b);
}

function serializarDn(dn: any) {
  return (dn?.attributes || [])
    .map((item: any) => `${item.type || item.shortName || item.name}=${String(item.value || "").trim()}`)
    .join("|");
}

function construirMensagemSefaz(partes: Array<unknown>) {
  return partes
    .map((parte) => String(parte ?? "").trim())
    .filter(Boolean)
    .filter((parte, indice, itens) => itens.indexOf(parte) === indice)
    .join(" | ");
}

async function consultarStatusSefaz(params: {
  sefaz: ReturnType<typeof resolverSefaz>;
  ambiente: number;
  uf: string;
  certificado: ReturnType<typeof parsePfx>;
}) {
  const xml = buildXml({
    consStatServ: {
      "@_xmlns": NFE_NS,
      "@_versao": "4.00",
      tpAmb: params.ambiente,
      cUF: obterCodigoUf(params.uf),
      xServ: "STATUS",
    },
  });

  const xmlRet = await enviarSoap({
    url: params.sefaz.statusServico,
    operacao: "NFeStatusServico4",
    metodo: "nfeStatusServicoNF",
    xml: xml,
    certificado: params.certificado,
  });

  const retorno = findNodeByLocalName(parser.parse(xmlRet), "retConsStatServ");
  const cStat = String(retorno?.cStat || "");
  const xMotivo = retorno?.xMotivo || null;
  return {
    success: true,
    cStat,
    xMotivo,
    cMsg: retorno?.cMsg || null,
    xMsg: retorno?.xMsg || null,
    tMed: retorno?.tMed,
    dhRecbto: retorno?.dhRecbto,
    conexao_ok: true,
    diagnostico: cStat === "999"
      ? "Conexao mTLS e SOAP realizadas com sucesso; a SEFAZ GO respondeu 999 no StatusServico."
      : null,
  };
}

async function emitirNfce(params: {
  sefaz: ReturnType<typeof resolverSefaz>;
  ambiente: number;
  uf: string;
  certificado: ReturnType<typeof parsePfx>;
  empresa: Record<string, unknown>;
  payload: any;
}) {
  if (!params.payload?.infNFe) {
    throw new Error("Payload da NFC-e nÃƒÂ£o informado");
  }

  const payload = structuredClone(params.payload);
  const infNFe = payload.infNFe;
  const ide = infNFe.ide;
  const emit = infNFe.emit;

  const cnpj = String(emit?.CNPJ || params.empresa.cnpj || "").replace(/\D/g, "");
  const modelo = String(ide.mod || 65).padStart(2, "0");
  const serie = String(ide.serie || params.empresa.nfce_serie || 1).padStart(3, "0");
  const numero = String(ide.nNF || params.empresa.nfce_numero || 1).padStart(9, "0");
  const tpEmis = String(ide.tpEmis || 1);
  const cNF = String(ide.cNF || gerarCodigoNumerico()).padStart(8, "0");
  const dhEmi = formatarDataHoraBrasil(ide.dhEmi);
  const aamm = `${dhEmi.slice(2, 4)}${dhEmi.slice(5, 7)}`;
  const baseChave = `${obterCodigoUf(params.uf)}${aamm}${cnpj}${modelo}${serie}${numero}${tpEmis}${cNF}`;
  const cDV = calcularDigitoChave(baseChave);
  const chaveAcesso = `${baseChave}${cDV}`;

  ide.cUF = obterCodigoUf(params.uf);
  ide.mod = 65;
  ide.serie = parseInt(String(ide.serie || params.empresa.nfce_serie || 1), 10);
  ide.nNF = parseInt(String(ide.nNF || params.empresa.nfce_numero || 1), 10);
  ide.dhEmi = dhEmi;
  ide.tpAmb = params.ambiente;
  ide.tpEmis = parseInt(tpEmis, 10);
  ide.cNF = cNF;
  ide.cDV = cDV;
  infNFe["@_Id"] = `NFe${chaveAcesso}`;
  infNFe["@_versao"] = "4.00";

  emit.CNPJ = cnpj;
  emit.CRT = parseInt(String(emit.CRT || params.empresa.regime_tributario_codigo || params.empresa.regime_tributario || 1), 10);
  normalizarCamposSchemaNfce(infNFe);

  const nfeObj = {
    NFe: {
      "@_xmlns": NFE_NS,
      infNFe: normalizarInfNFeParaXml(infNFe),
    },
  };

  const xmlSemAssinatura = buildXml(nfeObj);
  const xmlAssinado = assinarXml(xmlSemAssinatura, `#${infNFe["@_Id"]}`, params.certificado);
  const qrCode = await gerarQrCode({
    chaveAcesso,
    ambiente: params.ambiente,
    cscId: String(params.empresa.csc_id),
    cscToken: String(params.empresa.csc_token),
    qrCodeBaseUrl: params.sefaz.qrCodeUrl,
    infNFe,
    xmlAssinado,
  });
  const xmlAssinadoComSupl = inserirInfNFeSupl(xmlAssinado, qrCode, params.sefaz.urlChave);

  const enviNfeXml = `<?xml version="1.0" encoding="UTF-8"?><enviNFe xmlns="${NFE_NS}" versao="4.00"><idLote>${gerarIdLote()}</idLote><indSinc>1</indSinc>${removerDeclaracaoXml(xmlAssinadoComSupl)}</enviNFe>`;

  let xmlRet = "";
  try {
    xmlRet = await enviarSoap({
      url: params.sefaz.autorizacao,
      operacao: "NFeAutorizacao4",
      metodo: "nfeAutorizacaoLote",
      xml: enviNfeXml,
      certificado: params.certificado,
    });
  } catch (error) {
    const mensagemErro = error instanceof Error ? error.message : String(error);
    const xmlRetornoSefaz = (error as any)?.xmlRetornoSefaz || "";
    return {
      success: false,
      status: "rejeitado",
      codigo_status: "999",
      mensagem: mensagemErro,
      chave_acesso: chaveAcesso,
      numero: parseInt(numero, 10),
      serie: parseInt(serie, 10),
      xml_assinado: xmlAssinadoComSupl,
      xml_envio: enviNfeXml,
      xml_retorno: xmlRetornoSefaz || mensagemErro,
    };
  }

  const retorno = findNodeByLocalName(parser.parse(xmlRet), "retEnviNFe");
  const protNFe = retorno?.protNFe;
  const infProt = protNFe?.infProt;
  const cStat = String(infProt?.cStat || retorno?.cStat || "");
  const xMotivo = infProt?.xMotivo || retorno?.xMotivo || "Sem motivo retornado";
  const cMsg = infProt?.cMsg || retorno?.cMsg || null;
  const xMsg = infProt?.xMsg || retorno?.xMsg || null;
  const mensagemCompleta = construirMensagemSefaz([
    cStat ? `${cStat} - ${xMotivo}` : xMotivo,
    cMsg ? `cMsg ${cMsg}` : "",
    xMsg,
  ]);

  if (cStat !== "100" && cStat !== "150") {
    return {
      success: false,
      status: "rejeitado",
      codigo_status: cStat,
      mensagem: mensagemCompleta || xMotivo,
      cMsg,
      xMsg,
      chave_acesso: chaveAcesso,
      numero: parseInt(numero, 10),
      serie: parseInt(serie, 10),
      xml_assinado: xmlAssinadoComSupl,
      xml_envio: enviNfeXml,
      xml_retorno: xmlRet,
    };
  }

  const xmlProc = buildXml({
    nfeProc: {
      "@_xmlns": NFE_NS,
      "@_versao": "4.00",
      NFe: parser.parse(xmlAssinadoComSupl).NFe,
      protNFe: protNFe,
    },
  });

  return {
    success: true,
    status: "autorizado",
    codigo_status: cStat,
    mensagem: mensagemCompleta || xMotivo,
    cMsg,
    xMsg,
    numero: parseInt(numero, 10),
    serie: parseInt(serie, 10),
    chave_acesso: chaveAcesso,
    protocolo: infProt?.nProt || null,
    data_emissao: dhEmi,
    data_autorizacao: infProt?.dhRecbto || null,
    xml_assinado: xmlAssinadoComSupl,
    xml_proc: xmlProc,
    xml_retorno: xmlRet,
  };
}

async function consultarNfce(params: {
  sefaz: ReturnType<typeof resolverSefaz>;
  ambiente: number;
  uf: string;
  certificado: ReturnType<typeof parsePfx>;
  chaveAcesso: string;
}) {
  if (!params.chaveAcesso) {
    throw new Error("Chave de acesso nÃƒÂ£o informada");
  }

  const xml = buildXml({
    consSitNFe: {
      "@_xmlns": NFE_NS,
      "@_versao": "4.00",
      tpAmb: params.ambiente,
      xServ: "CONSULTAR",
      chNFe: params.chaveAcesso,
    },
  });

  const xmlRet = await enviarSoap({
    url: params.sefaz.consultaProtocolo,
    operacao: "NFeConsultaProtocolo4",
    metodo: "nfeConsultaNF",
    xml,
    certificado: params.certificado,
  });

  const retorno = findNodeByLocalName(parser.parse(xmlRet), "retConsSitNFe");
  const prot = retorno?.protNFe?.infProt;
  const status = String(prot?.cStat || retorno?.cStat || "");
  const cMsg = prot?.cMsg || retorno?.cMsg || null;
  const xMsg = prot?.xMsg || retorno?.xMsg || null;

  return {
    success: status === "100" || status === "135" || status === "150" || status === "101",
    status,
    status_sefaz: status,
    mensagem: construirMensagemSefaz([
      status ? `${status} - ${prot?.xMotivo || retorno?.xMotivo || ""}` : (prot?.xMotivo || retorno?.xMotivo || ""),
      cMsg ? `cMsg ${cMsg}` : "",
      xMsg,
    ]),
    cMsg,
    xMsg,
    protocolo: prot?.nProt || null,
    chave_acesso: params.chaveAcesso,
    xml_retorno: xmlRet,
    xml_proc: null,
  };
}

async function cancelarNfce(params: {
  sefaz: ReturnType<typeof resolverSefaz>;
  ambiente: number;
  uf: string;
  certificado: ReturnType<typeof parsePfx>;
  chaveAcesso: string;
  justificativa: string;
  protocoloAutorizacao?: string;
}) {
  if (!params.chaveAcesso) {
    throw new Error("Chave de acesso nÃƒÂ£o informada");
  }

  if (!params.justificativa || params.justificativa.length < 15) {
    throw new Error("A justificativa deve ter ao menos 15 caracteres");
  }

  const protocoloInformado = String(params.protocoloAutorizacao || "").replace(/\D/g, "");
  let protocoloCancelamento = protocoloInformado;

  if (!protocoloCancelamento) {
    const consulta = await consultarNfce(params);
    if (consulta.status_sefaz === "135" || consulta.status_sefaz === "101") {
      return {
        success: true,
        status: "cancelado",
        status_sefaz: "135",
        mensagem: "Documento ja se encontra cancelado na SEFAZ",
        protocolo: consulta.protocolo,
      };
    }

    if (consulta.status_sefaz !== "100" && consulta.status_sefaz !== "150") {
      const mensagem = construirMensagemSefaz([
        consulta.status_sefaz ? `${consulta.status_sefaz} - ${consulta.mensagem || "NF-e nao autorizada para cancelamento"}` : consulta.mensagem,
        "Confira se a chave pertence ao mesmo ambiente configurado e se a nota foi autorizada pela SEFAZ direta.",
      ]) || "NF-e nao autorizada para cancelamento";

      return {
        success: false,
        status: "rejeitado",
        status_sefaz: consulta.status_sefaz,
        mensagem,
        protocolo: consulta.protocolo,
        chave_acesso: params.chaveAcesso,
        xml_retorno: consulta.xml_retorno,
      };
    }

    protocoloCancelamento = String(consulta.protocolo || "").replace(/\D/g, "");
  }

  if (!protocoloCancelamento) {
    throw new Error("Nao foi possivel localizar o protocolo da NFC-e para cancelamento");
  }

  const dhEvento = formatarDataHoraBrasil();
  const idEvento = `ID110111${params.chaveAcesso}01`;

  const evento = {
    evento: {
      "@_xmlns": NFE_NS,
      "@_versao": "1.00",
      infEvento: {
        "@_Id": idEvento,
        cOrgao: obterCodigoUf(params.uf),
        tpAmb: params.ambiente,
        CNPJ: params.chaveAcesso.slice(6, 20),
        chNFe: params.chaveAcesso,
        dhEvento,
        tpEvento: "110111",
        nSeqEvento: 1,
        verEvento: "1.00",
        detEvento: {
          "@_versao": "1.00",
          descEvento: "Cancelamento",
          nProt: protocoloCancelamento,
          xJust: params.justificativa,
        },
      },
    },
  };

  const xmlEvento = buildXml(evento);
  const xmlEventoAssinado = assinarXml(xmlEvento, `#${idEvento}`, params.certificado, "//*[local-name(.)='infEvento']");
  const envEvento = `<?xml version="1.0" encoding="UTF-8"?><envEvento xmlns="${NFE_NS}" versao="1.00"><idLote>${gerarIdLote()}</idLote>${removerDeclaracaoXml(xmlEventoAssinado)}</envEvento>`;

  const xmlRet = await enviarSoap({
    url: params.sefaz.recepcaoEvento,
    operacao: "NFeRecepcaoEvento4",
    metodo: "nfeRecepcaoEvento",
    xml: envEvento,
    certificado: params.certificado,
  });

  const retorno = findNodeByLocalName(parser.parse(xmlRet), "retEnvEvento");
  const infEvento = retorno?.retEvento?.infEvento;
  const status = String(infEvento?.cStat || retorno?.cStat || "");
  const cMsg = infEvento?.cMsg || retorno?.cMsg || null;
  const xMsg = infEvento?.xMsg || retorno?.xMsg || null;

  if (status !== "135" && status !== "155") {
    return {
      success: false,
      status: "rejeitado",
      status_sefaz: status,
      mensagem: construirMensagemSefaz([
        status ? `${status} - ${infEvento?.xMotivo || retorno?.xMotivo || "Cancelamento rejeitado pela SEFAZ"}` : (infEvento?.xMotivo || retorno?.xMotivo || "Cancelamento rejeitado pela SEFAZ"),
        cMsg ? `cMsg ${cMsg}` : "",
        xMsg,
      ]) || "Cancelamento rejeitado pela SEFAZ",
      cMsg,
      xMsg,
      protocolo: infEvento?.nProt || null,
      chave_acesso: params.chaveAcesso,
      protocolo_autorizacao: protocoloCancelamento,
      xml_envio: envEvento,
      xml_retorno: xmlRet,
    };
  }

  return {
    success: true,
    status: "cancelado",
    status_sefaz: status,
    mensagem: construirMensagemSefaz([
      status ? `${status} - ${infEvento?.xMotivo || "Evento de cancelamento registrado"}` : (infEvento?.xMotivo || "Evento de cancelamento registrado"),
      cMsg ? `cMsg ${cMsg}` : "",
      xMsg,
    ]) || infEvento?.xMotivo || "Evento de cancelamento registrado",
    cMsg,
    xMsg,
    protocolo: infEvento?.nProt || null,
    xml_retorno: xmlRet,
  };
}

function normalizarInfNFeParaXml(infNFe: any) {
  return {
    "@_Id": infNFe["@_Id"],
    "@_versao": infNFe["@_versao"] || infNFe.versao || "4.00",
    ide: ordenarIdeNFe(infNFe.ide),
    emit: infNFe.emit,
    ...(infNFe.dest ? { dest: infNFe.dest } : {}),
    det: Array.isArray(infNFe.det)
      ? infNFe.det.map((item: any) => ({
        "@_nItem": item.nItem,
        prod: item.prod,
        imposto: item.imposto,
      }))
      : [],
    total: infNFe.total,
    transp: infNFe.transp,
    pag: infNFe.pag,
    ...(infNFe.infAdic ? { infAdic: infNFe.infAdic } : {}),
  };
}

function ordenarIdeNFe(ide: any) {
  const ordem = [
    "cUF", "cNF", "natOp", "mod", "serie", "nNF", "dhEmi", "dhSaiEnt", "tpNF", "idDest",
    "cMunFG", "tpImp", "tpEmis", "cDV", "tpAmb", "finNFe", "indFinal", "indPres", "indIntermed",
    "procEmi", "verProc", "dhCont", "xJust",
  ];
  return ordenarObjetoPorCampos(ide || {}, ordem);
}

function ordenarObjetoPorCampos(obj: Record<string, unknown>, ordem: string[]) {
  const ordenado: Record<string, unknown> = {};
  for (const campo of ordem) {
    if (obj[campo] !== undefined && obj[campo] !== null && obj[campo] !== "") {
      ordenado[campo] = obj[campo];
    }
  }
  for (const [campo, valor] of Object.entries(obj)) {
    if (!(campo in ordenado) && valor !== undefined && valor !== null && valor !== "") {
      ordenado[campo] = valor;
    }
  }
  return ordenado;
}

function normalizarCamposSchemaNfce(infNFe: any) {
  if (Array.isArray(infNFe.det)) {
    infNFe.det.forEach((det: any, index: number) => {
      det.nItem = parseInt(String(det.nItem || index + 1), 10);
      const prod = det.prod || {};
      prod.cProd = String(prod.cProd || index + 1).replace(/[^A-Za-z0-9]/g, "").slice(0, 60) || String(index + 1);
      prod.xProd = String(prod.xProd || "PRODUTO").slice(0, 120);
      prod.NCM = String(prod.NCM || "00000000").replace(/\D/g, "").padStart(8, "0").slice(0, 8);
      prod.CFOP = String(prod.CFOP || "5102").replace(/\D/g, "").slice(0, 4);
      prod.uCom = String(prod.uCom || "UN").slice(0, 6);
      prod.uTrib = String(prod.uTrib || prod.uCom || "UN").slice(0, 6);
      prod.qCom = formatarDecimalSchema(prod.qCom, 4);
      prod.qTrib = formatarDecimalSchema(prod.qTrib ?? prod.qCom, 4);
      prod.vUnCom = formatarDecimalSchema(prod.vUnCom, 10);
      prod.vUnTrib = formatarDecimalSchema(prod.vUnTrib ?? prod.vUnCom, 10);
      prod.vProd = formatarDecimalSchema(prod.vProd, 2);
      prod.cEAN = normalizarGtin(prod.cEAN);
      prod.cEANTrib = normalizarGtin(prod.cEANTrib);
      det.prod = prod;
    });
    if (parseInt(String(infNFe.ide?.tpAmb || 2), 10) === 2 && infNFe.det[0]?.prod) {
      infNFe.det[0].prod.xProd = "NOTA FISCAL EMITIDA EM AMBIENTE DE HOMOLOGACAO - SEM VALOR FISCAL";
    }
  }

  const total = infNFe.total?.ICMSTot;
  if (total) {
    [
      "vBC", "vICMS", "vICMSDeson", "vFCP", "vBCST", "vST", "vFCPST", "vFCPSTRet",
      "vProd", "vFrete", "vSeg", "vDesc", "vII", "vIPI", "vIPIDevol", "vPIS", "vCOFINS",
      "vOutro", "vNF", "vTotTrib",
    ].forEach((campo) => {
      if (total[campo] !== undefined && total[campo] !== null) {
        total[campo] = formatarDecimalSchema(total[campo], 2);
      }
    });
  }

  const detPag = infNFe.pag?.detPag;
  const pagamentos = Array.isArray(detPag) ? detPag : (detPag ? [detPag] : []);
  pagamentos.forEach((pag: any) => {
    pag.tPag = String(pag.tPag || "99").replace(/\D/g, "").padStart(2, "0").slice(0, 2);
    pag.vPag = formatarDecimalSchema(pag.vPag, 2);
    if (pag.tPag !== "99") {
      delete pag.xPag;
    }
  });
  if (infNFe.pag?.vTroco !== undefined && infNFe.pag?.vTroco !== null) {
    infNFe.pag.vTroco = formatarDecimalSchema(infNFe.pag.vTroco, 2);
  }
}

function normalizarGtin(valor: unknown) {
  const texto = String(valor || "").trim();
  if (!texto || /^sem\s*gtin$/i.test(texto)) {
    return "SEM GTIN";
  }
  return texto.replace(/\D/g, "") || "SEM GTIN";
}

function formatarDecimalSchema(valor: unknown, casas: number) {
  const numero = Number(String(valor ?? 0).replace(",", "."));
  return (Number.isFinite(numero) ? numero : 0).toFixed(casas);
}

function buildXml(obj: unknown) {
  return create({ version: "1.0", encoding: "UTF-8" }, normalizarAtributosXmlBuilder(obj) as Record<string, unknown>).end({
    prettyPrint: false,
  });
}

function normalizarAtributosXmlBuilder(valor: unknown): unknown {
  if (Array.isArray(valor)) {
    return valor.map((item) => normalizarAtributosXmlBuilder(item));
  }

  if (!valor || typeof valor !== "object") {
    return valor;
  }

  const normalizado: Record<string, unknown> = {};
  for (const [chave, item] of Object.entries(valor as Record<string, unknown>)) {
    const chaveNormalizada = chave.startsWith("@_")
      ? `@${chave.slice(2)}`
      : chave;
    normalizado[chaveNormalizada] = normalizarAtributosXmlBuilder(item);
  }

  return normalizado;
}

function removerDeclaracaoXml(xml: string) {
  return String(xml || "").replace(/^\s*<\?xml[^>]*\?>\s*/i, "");
}

function assinarXml(
  xml: string,
  referenceUri: string,
  certificado: ReturnType<typeof parsePfx>,
  xpath = "//*[local-name(.)='infNFe']",
) {
  const signer = new SignedXml({
    privateKey: certificado.privateKeyPem,
    publicCert: certificado.certPem,
    canonicalizationAlgorithm: "http://www.w3.org/TR/2001/REC-xml-c14n-20010315",
    signatureAlgorithm: "http://www.w3.org/2000/09/xmldsig#rsa-sha1",
  });

  signer.addReference({
    xpath,
    transforms: [
      "http://www.w3.org/2000/09/xmldsig#enveloped-signature",
      "http://www.w3.org/TR/2001/REC-xml-c14n-20010315",
    ],
    digestAlgorithm: "http://www.w3.org/2000/09/xmldsig#sha1",
    id: referenceUri.replace(/^#/, ""),
  });

  signer.computeSignature(xml, {
    location: {
      reference: "//*[local-name(.)='NFe' or local-name(.)='evento']",
      action: "append",
    },
  });

  return signer.getSignedXml();
}

async function gerarQrCode(params: {
  chaveAcesso: string;
  ambiente: number;
  cscId: string;
  cscToken: string;
  qrCodeBaseUrl: string;
  infNFe: any;
  xmlAssinado: string;
}) {
  const ide = params.infNFe?.ide || {};
  const total = params.infNFe?.total?.ICMSTot || {};
  const digestValue = String(findNodeByLocalName(parser.parse(params.xmlAssinado), "DigestValue") || "");
  const dhEmiHex = stringToHex(String(ide.dhEmi || ""));
  const digValHex = stringToHex(digestValue);
  const cDest = String(params.infNFe?.dest?.CPF || params.infNFe?.dest?.CNPJ || "").replace(/\D/g, "");
  const idToken = String(params.cscId || "").replace(/\D/g, "").replace(/^0+/, "") || "0";
  const tpEmis = parseInt(String(ide.tpEmis || 1), 10);
  const dadosQr = tpEmis === 9
    ? [
      params.chaveAcesso,
      "2",
      String(params.ambiente),
      cDest,
      dhEmiHex,
      formatarDecimalSchema(total.vNF, 2),
      formatarDecimalSchema(total.vICMS, 2),
      digValHex,
      idToken,
    ].join("|")
    : [
      params.chaveAcesso,
      "2",
      String(params.ambiente),
      idToken,
    ].join("|");
  const hash = await sha1Hex(`${dadosQr}${params.cscToken}`);

  return `${params.qrCodeBaseUrl}?p=${dadosQr}|${hash}`;
}

function inserirInfNFeSupl(xmlAssinado: string, qrCode: string, urlChave: string) {
  const supl = `<infNFeSupl><qrCode>${escapeXml(qrCode.trim())}</qrCode><urlChave>${escapeXml(urlChave)}</urlChave></infNFeSupl>`;
  return String(xmlAssinado).replace("<Signature xmlns=\"http://www.w3.org/2000/09/xmldsig#\">", `${supl}<Signature xmlns=\"http://www.w3.org/2000/09/xmldsig#\">`);
}

async function sha1Hex(texto: string) {
  const hashBuffer = await crypto.subtle.digest("SHA-1", new TextEncoder().encode(texto));
  return Array.from(new Uint8Array(hashBuffer))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")
    .toUpperCase();
}

function stringToHex(texto: string) {
  return Array.from(new TextEncoder().encode(texto))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")
    .toUpperCase();
}

function escapeXml(valor: string) {
  return String(valor || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function formatarDataHoraBrasil(data?: string) {
  const date = data ? new Date(data) : new Date();
  const emSaoPaulo = new Date(date.toLocaleString("en-US", { timeZone: "America/Sao_Paulo" }));
  const ano = emSaoPaulo.getFullYear();
  const mes = String(emSaoPaulo.getMonth() + 1).padStart(2, "0");
  const dia = String(emSaoPaulo.getDate()).padStart(2, "0");
  const hora = String(emSaoPaulo.getHours()).padStart(2, "0");
  const minuto = String(emSaoPaulo.getMinutes()).padStart(2, "0");
  const segundo = String(emSaoPaulo.getSeconds()).padStart(2, "0");
  return `${ano}-${mes}-${dia}T${hora}:${minuto}:${segundo}-03:00`;
}

function gerarCodigoNumerico() {
  return Math.floor(10000000 + Math.random() * 90000000);
}

function gerarIdLote() {
  return String(Date.now()).slice(-15);
}

function calcularDigitoChave(chave43: string) {
  let multiplicador = 2;
  let soma = 0;

  for (let i = chave43.length - 1; i >= 0; i -= 1) {
    soma += parseInt(chave43[i], 10) * multiplicador;
    multiplicador = multiplicador === 9 ? 2 : multiplicador + 1;
  }

  const resto = soma % 11;
  return resto === 0 || resto === 1 ? 0 : 11 - resto;
}

function obterCodigoUf(uf: string) {
  const mapa: Record<string, string> = {
    RO: "11",
    AC: "12",
    AM: "13",
    RR: "14",
    PA: "15",
    AP: "16",
    TO: "17",
    MA: "21",
    PI: "22",
    CE: "23",
    RN: "24",
    PB: "25",
    PE: "26",
    AL: "27",
    SE: "28",
    BA: "29",
    MG: "31",
    ES: "32",
    RJ: "33",
    SP: "35",
    PR: "41",
    SC: "42",
    RS: "43",
    MS: "50",
    MT: "51",
    GO: "52",
    DF: "53",
  };

  const codigo = mapa[String(uf || "").toUpperCase()];
  if (!codigo) {
    throw new Error(`UF invÃƒÂ¡lida para NFC-e: ${uf}`);
  }

  return codigo;
}

async function enviarSoap(params: {
  url: string;
  operacao: string;
  metodo: string;
  xml: string;
  certificado: ReturnType<typeof parsePfx>;
}) {
  const action = `${NFE_NS}/wsdl/${params.operacao}/${params.metodo}`;
  const xmlSemDeclaracao = removerDeclaracaoXml(params.xml);
  const envelopes = [
    {
      nome: "soap12_operacao_action",
      action,
      versao: "1.2" as const,
      xml: montarEnvelopeSoapOperacao(params.operacao, params.metodo, xmlSemDeclaracao, "1.2"),
    },
    {
      nome: "soap12_operacao_sem_action",
      action: "",
      versao: "1.2" as const,
      xml: montarEnvelopeSoapOperacao(params.operacao, params.metodo, xmlSemDeclaracao, "1.2"),
    },
    {
      nome: "soap12_dados_action",
      action,
      versao: "1.2" as const,
      xml: montarEnvelopeSoapDados(params.operacao, xmlSemDeclaracao, "1.2"),
    },
    {
      nome: "soap12_prefixed_action",
      action,
      versao: "1.2" as const,
      xml: montarEnvelopeSoapOperacaoPrefixada(params.operacao, params.metodo, xmlSemDeclaracao),
    },
    {
      nome: "soap12_dados_prefixed_action",
      action,
      versao: "1.2" as const,
      xml: montarEnvelopeSoapDadosPrefixado(params.operacao, xmlSemDeclaracao),
    },
    {
      nome: "soap12_header_action",
      action,
      versao: "1.2" as const,
      xml: montarEnvelopeSoapComCabecalho(params.operacao, params.metodo, xmlSemDeclaracao, obterVersaoDados(params.operacao)),
    },
    {
      nome: "soap11_operacao_action",
      action,
      versao: "1.1" as const,
      xml: montarEnvelopeSoapOperacao(params.operacao, params.metodo, xmlSemDeclaracao, "1.1"),
    },
  ];

  const tentativas: string[] = [];
  let ultimoRetorno999 = "";
  let ultimoErro: Error | null = null;

  for (const envelope of envelopes) {
    try {
      const xmlRet = await enviarSoapEnvelope({
        url: params.url,
        action: envelope.action,
        versao: envelope.versao,
        envelope: envelope.xml,
        certificado: params.certificado,
      });

      const cStat = String(findNodeByLocalName(parser.parse(xmlRet), "cStat") || "");
      const xMotivo = String(findNodeByLocalName(parser.parse(xmlRet), "xMotivo") || "");
      if (cStat && cStat !== "999") {
        return xmlRet;
      }

      tentativas.push(`${envelope.nome}: ${cStat || "sem cStat"} - ${xMotivo || "Sem motivo"}`);
      if (cStat === "999") {
        ultimoRetorno999 = xmlRet;
      }
    } catch (error) {
      ultimoErro = error instanceof Error ? error : new Error(String(error));
      tentativas.push(`${envelope.nome}: ${ultimoErro.message}`);
    }
  }

  if (ultimoRetorno999) {
    const erro = new Error(`SEFAZ retornou 999 em todas as tentativas SOAP: ${tentativas.join(" || ")}`);
    (erro as any).xmlRetornoSefaz = ultimoRetorno999;
    throw erro;
  }

  throw ultimoErro || new Error(`Falha ao enviar SOAP para a SEFAZ: ${tentativas.join(" || ")}`);
}

async function enviarSoapEnvelope(params: {
  url: string;
  action: string;
  versao: "1.1" | "1.2";
  envelope: string;
  certificado: ReturnType<typeof parsePfx>;
}) {
  let response: {
    status: number;
    body: string;
  };
  try {
    response = await enviarHttpsMutualTls({
      url: params.url,
      body: params.envelope,
      certificado: params.certificado,
      headers: montarHeadersSoap(params.action, params.versao),
    });
  } catch (error) {
    const mensagem = error instanceof Error ? error.message : String(error);
    if (/HandshakeFailure/i.test(mensagem)) {
      throw new Error(
        `Falha no handshake TLS com a SEFAZ em ${params.url}. Certificado: ${params.certificado.subject}. Emissor: ${params.certificado.issuer}. Cadeia enviada: ${params.certificado.chainLength} certificado(s). Erro original: ${mensagem}`,
      );
    }

    throw new Error(`Falha ao conectar na SEFAZ em ${params.url}. Certificado: ${params.certificado.subject}. Cadeia enviada: ${params.certificado.chainLength} certificado(s). Erro original: ${mensagem}`);
  }

  if (response.status < 200 || response.status >= 300) {
    throw new Error(`SEFAZ retornou HTTP ${response.status}: ${response.body}`);
  }

  return response.body;
}

function montarEnvelopeSoapOperacao(operacao: string, metodo: string, xmlSemDeclaracao: string, versao: "1.1" | "1.2") {
  if (versao === "1.1") {
    return `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:xsd="http://www.w3.org/2001/XMLSchema"
               xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <${metodo} xmlns="${NFE_NS}/wsdl/${operacao}">
      <nfeDadosMsg>${xmlSemDeclaracao}</nfeDadosMsg>
    </${metodo}>
  </soap:Body>
</soap:Envelope>`;
  }

  return `<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                 xmlns:soap12="${SOAP_NS}">
  <soap12:Body>
    <${metodo} xmlns="${NFE_NS}/wsdl/${operacao}">
      <nfeDadosMsg>${xmlSemDeclaracao}</nfeDadosMsg>
    </${metodo}>
  </soap12:Body>
</soap12:Envelope>`;
}

function montarEnvelopeSoapDadosPrefixado(operacao: string, xmlSemDeclaracao: string) {
  return `<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                 xmlns:soap12="${SOAP_NS}"
                 xmlns:ns1="${NFE_NS}/wsdl/${operacao}">
  <soap12:Body>
    <ns1:nfeDadosMsg>${xmlSemDeclaracao}</ns1:nfeDadosMsg>
  </soap12:Body>
</soap12:Envelope>`;
}

function montarEnvelopeSoapOperacaoPrefixada(operacao: string, metodo: string, xmlSemDeclaracao: string) {
  return `<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                 xmlns:soap12="${SOAP_NS}"
                 xmlns:ns1="${NFE_NS}/wsdl/${operacao}">
  <soap12:Body>
    <ns1:${metodo}>
      <nfeDadosMsg>${xmlSemDeclaracao}</nfeDadosMsg>
    </ns1:${metodo}>
  </soap12:Body>
</soap12:Envelope>`;
}

function montarEnvelopeSoapComCabecalho(operacao: string, metodo: string, xmlSemDeclaracao: string, versaoDados: string) {
  return `<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                 xmlns:soap12="${SOAP_NS}">
  <soap12:Header>
    <nfeCabecMsg xmlns="${NFE_NS}/wsdl/${operacao}">
      <cUF>52</cUF>
      <versaoDados>${versaoDados}</versaoDados>
    </nfeCabecMsg>
  </soap12:Header>
  <soap12:Body>
    <${metodo} xmlns="${NFE_NS}/wsdl/${operacao}">
      <nfeDadosMsg>${xmlSemDeclaracao}</nfeDadosMsg>
    </${metodo}>
  </soap12:Body>
</soap12:Envelope>`;
}

function obterVersaoDados(operacao: string) {
  return operacao === "NFeRecepcaoEvento4" ? "1.00" : "4.00";
}

function montarEnvelopeSoapDados(operacao: string, xmlSemDeclaracao: string, versao: "1.1" | "1.2") {
  if (versao === "1.1") {
    return `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:xsd="http://www.w3.org/2001/XMLSchema"
               xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <nfeDadosMsg xmlns="${NFE_NS}/wsdl/${operacao}">${xmlSemDeclaracao}</nfeDadosMsg>
  </soap:Body>
</soap:Envelope>`;
  }

  return `<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                 xmlns:soap12="${SOAP_NS}">
  <soap12:Body>
    <nfeDadosMsg xmlns="${NFE_NS}/wsdl/${operacao}">${xmlSemDeclaracao}</nfeDadosMsg>
  </soap12:Body>
</soap12:Envelope>`;
}

function montarHeadersSoap(action: string, versao: "1.1" | "1.2") {
  if (versao === "1.1") {
    const headers: Record<string, string> = {
      "Content-Type": "text/xml; charset=utf-8",
      "Accept": "application/soap+xml, application/xml, text/xml",
    };
    if (action) {
      headers.SOAPAction = `"${action}"`;
    }
    return headers;
  }

  const contentType = action
    ? `application/soap+xml; charset=utf-8; action="${action}"`
    : "application/soap+xml; charset=utf-8";

  return {
    "Content-Type": contentType,
    "Accept": "application/soap+xml, application/xml, text/xml",
  };
}

async function enviarHttpsMutualTls(params: {
  url: string;
  body: string;
  certificado: ReturnType<typeof parsePfx>;
  headers: Record<string, string>;
}) {
  const proxyUrl = String(Deno.env.get("SEFAZ_SOAP_PROXY_URL") || "").trim();
  if (proxyUrl) {
    return await enviarSoapViaProxy({
      proxyUrl,
      url: params.url,
      body: params.body,
      headers: params.headers,
      certificado: params.certificado,
    });
  }

  const destino = new URL(params.url);
  const hostname = destino.hostname;
  const port = destino.port ? parseInt(destino.port, 10) : 443;
  const path = `${destino.pathname || "/"}${destino.search || ""}`;
  const bodyBytes = new TextEncoder().encode(params.body);
  const headerLines = [
    `POST ${path} HTTP/1.1`,
    `Host: ${hostname}`,
    "Connection: close",
    "Expect:",
    `Content-Length: ${bodyBytes.length}`,
    ...Object.entries(params.headers).map(([key, value]) => `${key}: ${value}`),
    "",
    "",
  ];

  const conn = await Deno.connectTls({
    hostname,
    port,
    cert: params.certificado.certChainPem,
    key: params.certificado.privateKeyPem,
    alpnProtocols: ["http/1.1"],
  });

  try {
    const headerBytes = new TextEncoder().encode(headerLines.join("\r\n"));
    await conn.write(headerBytes);
    await conn.write(bodyBytes);

    const chunks: Uint8Array[] = [];
    const buffer = new Uint8Array(16 * 1024);
    while (true) {
      const n = await conn.read(buffer);
      if (n === null) {
        break;
      }
      chunks.push(buffer.slice(0, n));
    }

    const rawBytes = concatenarBytes(chunks);
    const rawText = new TextDecoder().decode(rawBytes);
    return parseHttpResponse(rawText);
  } finally {
    conn.close();
  }
}

async function enviarSoapViaProxy(params: {
  proxyUrl: string;
  url: string;
  body: string;
  certificado: ReturnType<typeof parsePfx>;
  headers: Record<string, string>;
}) {
  const secret = String(Deno.env.get("SEFAZ_SOAP_PROXY_SECRET") || "").trim();
  if (!secret) {
    throw new Error("SEFAZ_SOAP_PROXY_SECRET nao configurado na Edge Function");
  }

  const response = await fetch(params.proxyUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-sefaz-proxy-secret": secret,
    },
    body: JSON.stringify({
      url: params.url,
      body: params.body,
      headers: params.headers,
      certChainPem: params.certificado.certChainPem,
      privateKeyPem: params.certificado.privateKeyPem,
    }),
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data?.erro || `Proxy SEFAZ retornou HTTP ${response.status}`);
  }

  return {
    status: Number(data?.status || 0),
    body: String(data?.body || ""),
  };
}

function concatenarBytes(chunks: Uint8Array[]) {
  const total = chunks.reduce((acc, chunk) => acc + chunk.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    out.set(chunk, offset);
    offset += chunk.length;
  }
  return out;
}

function parseHttpResponse(raw: string) {
  const headerEnd = raw.indexOf("\r\n\r\n");
  if (headerEnd === -1) {
    throw new Error(`Resposta HTTP invalida da SEFAZ: ${raw.slice(0, 500)}`);
  }

  const headerText = raw.slice(0, headerEnd);
  const bodyText = raw.slice(headerEnd + 4);
  const headerLines = headerText.split(/\r\n/);
  const statusMatch = headerLines[0]?.match(/^HTTP\/\d(?:\.\d)?\s+(\d+)/);
  if (!statusMatch) {
    throw new Error(`Status HTTP invalido da SEFAZ: ${headerLines[0] || ""}`);
  }

  const headers = new Map<string, string>();
  for (const line of headerLines.slice(1)) {
    const sep = line.indexOf(":");
    if (sep > -1) {
      headers.set(line.slice(0, sep).trim().toLowerCase(), line.slice(sep + 1).trim());
    }
  }

  const body = headers.get("transfer-encoding")?.toLowerCase().includes("chunked")
    ? decodificarChunked(bodyText)
    : bodyText;

  return {
    status: parseInt(statusMatch[1], 10),
    body,
  };
}

function decodificarChunked(body: string) {
  let pos = 0;
  let out = "";

  while (pos < body.length) {
    const lineEnd = body.indexOf("\r\n", pos);
    if (lineEnd === -1) {
      break;
    }

    const sizeText = body.slice(pos, lineEnd).split(";", 1)[0].trim();
    const size = parseInt(sizeText, 16);
    if (!Number.isFinite(size) || size < 0) {
      return body;
    }
    if (size === 0) {
      break;
    }

    const chunkStart = lineEnd + 2;
    out += body.slice(chunkStart, chunkStart + size);
    pos = chunkStart + size + 2;
  }

  return out;
}

function findNodeByLocalName(node: any, localName: string): any {
  if (!node || typeof node !== "object") {
    return null;
  }

  for (const [key, value] of Object.entries(node)) {
    const cleanKey = key.includes(":") ? key.split(":").pop() : key;
    if (cleanKey === localName) {
      return value;
    }

    if (typeof value === "object") {
      const nested = findNodeByLocalName(value, localName);
      if (nested) {
        return nested;
      }
    }
  }

  return null;
}
