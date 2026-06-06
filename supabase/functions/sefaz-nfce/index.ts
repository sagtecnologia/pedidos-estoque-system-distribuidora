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
      throw new Error("Ação não informada");
    }

    if (action === "validar_certificado") {
      const certificado = body?.certificado;
      const senha = body?.senha;

      if (!certificado || !senha) {
        throw new Error("Certificado e senha são obrigatórios");
      }

      const material = parsePfx(certificado, senha);
      return jsonResponse({
        success: true,
        validade: material.validToIsoDate,
        subject: material.subject,
        issuer: material.issuer,
        serial_number: material.serialNumber,
        chain_length: material.chainLength,
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
          chaveAcesso: body?.chave_acesso,
        }));
      case "cancelar":
        return jsonResponse(await cancelarNfce({
          sefaz,
          ambiente,
          uf,
          certificado,
          chaveAcesso: body?.chave_acesso,
          justificativa: body?.justificativa,
        }));
      default:
        throw new Error(`Ação não suportada: ${action}`);
    }
  } catch (error) {
    console.error("[sefaz-nfce] erro:", error);
    return jsonResponse(
      { erro: error instanceof Error ? error.message : "Erro interno da função" },
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
    throw new Error("Configuração da empresa não encontrada");
  }

  if (!data.certificado_digital || !data.senha_certificado) {
    throw new Error("Certificado digital A1 não configurado");
  }

  if (!data.csc_id || !data.csc_token) {
    throw new Error("CSC ID e CSC Token não configurados");
  }

  return data;
}

function normalizarAmbiente(ambiente: unknown) {
  return parseInt(String(ambiente || 2), 10) === 1 ? 1 : 2;
}

function resolverSefaz(uf: string, ambiente: number) {
  if (uf !== "GO") {
    throw new Error(`SEFAZ direta ainda não está mapeada para a UF ${uf}. Esta implementação cobre Goiás.`);
  }

  const base = ambiente === 1
    ? "https://nfe.sefaz.go.gov.br/nfe/services"
    : "https://homolog.sefaz.go.gov.br/nfe/services";

  return {
    autorizacao: `${base}/NFeAutorizacao4`,
    consultaProtocolo: `${base}/NFeConsultaProtocolo4`,
    statusServico: `${base}/NFeStatusServico4`,
    recepcaoEvento: `${base}/NFeRecepcaoEvento4`,
    qrCodeUrl: ambiente === 1
      ? "https://nfeweb.sefaz.go.gov.br/nfeweb/sites/nfce/danfeNFCe"
      : "https://homolog.sefaz.go.gov.br/nfeweb/sites/nfce/danfeNFCe",
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
    throw new Error("Não foi possível extrair chave privada e certificado do arquivo PFX");
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
  return {
    success: true,
    cStat: retorno?.cStat,
    xMotivo: retorno?.xMotivo,
    cMsg: retorno?.cMsg || null,
    xMsg: retorno?.xMsg || null,
    tMed: retorno?.tMed,
    dhRecbto: retorno?.dhRecbto,
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
    throw new Error("Payload da NFC-e não informado");
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

  const qrCode = await gerarQrCode({
    chaveAcesso,
    ambiente: params.ambiente,
    cscId: String(params.empresa.csc_id),
    cscToken: String(params.empresa.csc_token),
    qrCodeBaseUrl: params.sefaz.qrCodeUrl,
  });

  const nfeObj = {
    NFe: {
      "@_xmlns": NFE_NS,
      infNFe: normalizarInfNFeParaXml(infNFe),
      infNFeSupl: {
        qrCode,
        urlChave: params.sefaz.urlChave,
      },
    },
  };

  const xmlSemAssinatura = buildXml(nfeObj);
  const xmlAssinado = assinarXml(xmlSemAssinatura, `#${infNFe["@_Id"]}`, params.certificado);

  const enviNfeXml = buildXml({
    enviNFe: {
      "@_xmlns": NFE_NS,
      "@_versao": "4.00",
      idLote: gerarIdLote(),
      indSinc: 1,
      NFe: parser.parse(xmlAssinado).NFe,
    },
  });

  const xmlRet = await enviarSoap({
    url: params.sefaz.autorizacao,
    operacao: "NFeAutorizacao4",
    metodo: "nfeAutorizacaoLote",
    xml: enviNfeXml,
    certificado: params.certificado,
  });

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
      xml_assinado: xmlAssinado,
      xml_retorno: xmlRet,
    };
  }

  const xmlProc = buildXml({
    nfeProc: {
      "@_xmlns": NFE_NS,
      "@_versao": "4.00",
      NFe: parser.parse(xmlAssinado).NFe,
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
    xml_assinado: xmlAssinado,
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
    throw new Error("Chave de acesso não informada");
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
}) {
  if (!params.chaveAcesso) {
    throw new Error("Chave de acesso não informada");
  }

  if (!params.justificativa || params.justificativa.length < 15) {
    throw new Error("A justificativa deve ter ao menos 15 caracteres");
  }

  const consulta = await consultarNfce(params);
  if (consulta.status_sefaz === "135" || consulta.status_sefaz === "101") {
    return {
      success: true,
      status: "cancelado",
      status_sefaz: "135",
      mensagem: "Documento já se encontra cancelado na SEFAZ",
      protocolo: consulta.protocolo,
    };
  }

  if (!consulta.protocolo) {
    throw new Error("Não foi possível localizar o protocolo da NFC-e para cancelamento");
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
          nProt: consulta.protocolo,
          xJust: params.justificativa,
        },
      },
    },
  };

  const xmlEvento = buildXml(evento);
  const xmlEventoAssinado = assinarXml(xmlEvento, `#${idEvento}`, params.certificado, "//*[local-name(.)='infEvento']");
  const eventoObj = parser.parse(xmlEventoAssinado).evento;

  const envEvento = buildXml({
    envEvento: {
      "@_xmlns": NFE_NS,
      "@_versao": "1.00",
      idLote: gerarIdLote(),
      evento: eventoObj,
    },
  });

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
    throw new Error(
      construirMensagemSefaz([
        status ? `${status} - ${infEvento?.xMotivo || retorno?.xMotivo || "Cancelamento rejeitado pela SEFAZ"}` : (infEvento?.xMotivo || retorno?.xMotivo || "Cancelamento rejeitado pela SEFAZ"),
        cMsg ? `cMsg ${cMsg}` : "",
        xMsg,
      ]) || "Cancelamento rejeitado pela SEFAZ",
    );
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
    ide: infNFe.ide,
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

function buildXml(obj: unknown) {
  return create({ version: "1.0", encoding: "UTF-8" }, obj as Record<string, unknown>).end({
    prettyPrint: false,
  });
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
    uri: referenceUri,
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
}) {
  const dados = `${params.chaveAcesso}|2|${params.ambiente}|${params.cscId}|${params.cscToken}`;
  const hashBuffer = await crypto.subtle.digest("SHA-1", new TextEncoder().encode(dados));
  const hash = Array.from(new Uint8Array(hashBuffer))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")
    .toUpperCase();

  return `${params.qrCodeBaseUrl}?p=${params.chaveAcesso}|2|${params.ambiente}|${params.cscId}|${hash}`;
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
    throw new Error(`UF inválida para NFC-e: ${uf}`);
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
  const envelope = `<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                 xmlns:soap12="${SOAP_NS}">
  <soap12:Body>
    <${params.metodo} xmlns="${NFE_NS}/wsdl/${params.operacao}">
      <nfeDadosMsg>${xmlSemDeclaracao}</nfeDadosMsg>
    </${params.metodo}>
  </soap12:Body>
</soap12:Envelope>`;

  const client = Deno.createHttpClient({
    cert: params.certificado.certChainPem,
    key: params.certificado.privateKeyPem,
    http1: true,
    http2: false,
  });

  let response: Response;
  try {
    // @ts-ignore Deno fetch accepts the custom client option.
    response = await fetch(params.url, {
      method: "POST",
      client,
      headers: {
        "Content-Type": `application/soap+xml; charset=utf-8; action="${action}"`,
        "Accept": "application/soap+xml, application/xml, text/xml",
      },
      body: envelope,
    });
  } catch (error) {
    const mensagem = error instanceof Error ? error.message : String(error);
    if (/HandshakeFailure/i.test(mensagem)) {
      throw new Error(
        `Falha no handshake TLS com a SEFAZ em ${params.url}. Verifique se o PFX A1 contém a cadeia ICP-Brasil completa, se a chave privada corresponde ao certificado e se o ambiente configurado está correto.`,
      );
    }

    throw new Error(`Falha ao conectar na SEFAZ em ${params.url}: ${mensagem}`);
  }

  const text = await response.text();

  if (!response.ok) {
    throw new Error(`SEFAZ retornou HTTP ${response.status}: ${text}`);
  }

  return text;
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
