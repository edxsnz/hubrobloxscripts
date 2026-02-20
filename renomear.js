const fs = require('fs');
const path = require('path');

// Função para extrair o número do início do arquivo
function extrairNumeroOriginal(nomeArquivo) {
    const match = nomeArquivo.match(/^(\d+)/);
    return match ? parseInt(match[1]) : null;
}

// Função para extrair o nome real (remove a numeração do início)
function extrairNomeReal(nomeArquivo) {
    return nomeArquivo.replace(/^\d+\s*[-]?\s*/, '');
}

// Função para formatar o número com dois dígitos
function formatarNumero(numero) {
    return numero < 10 ? `0${numero}` : numero.toString();
}

// Função para verificar se o arquivo já está com o formato correto
function arquivoJaEstaCorreto(nomeArquivo, numeroEsperado, nomeReal) {
    const regex = new RegExp(`^${formatarNumero(numeroEsperado)} - ${nomeReal}\\.mp4$`);
    return regex.test(nomeArquivo);
}

// Função para verificar se a pasta já está com o formato correto
function pastaJaEstaCorreta(nomePasta, numeroEsperado, nomeReal) {
    const regex = new RegExp(`^${formatarNumero(numeroEsperado)} - ${nomeReal}\\.trickplay$`);
    return regex.test(nomePasta);
}

// Função principal de renomeação
function renomearArquivos(caminhoPasta) {
    try {
        console.log('\n🔍 INICIANDO RENOMEAÇÃO...');
        console.log('='.repeat(60));

        const itens = fs.readdirSync(caminhoPasta);
        const arquivosMP4 = [];
        const pastasTrickplay = [];

        // Separar MP4s e pastas
        itens.forEach(item => {
            const caminhoCompleto = path.join(caminhoPasta, item);
            const stats = fs.statSync(caminhoCompleto);

            if (stats.isFile() && item.toLowerCase().endsWith('.mp4')) {
                const numero = extrairNumeroOriginal(item);
                arquivosMP4.push({
                    nomeOriginal: item,
                    numero: numero,
                    nomeReal: extrairNomeReal(item.replace('.mp4', ''))
                });
            }
            else if (stats.isDirectory() && item.toLowerCase().endsWith('.trickplay')) {
                const numero = extrairNumeroOriginal(item);
                pastasTrickplay.push({
                    nomeOriginal: item,
                    numero: numero,
                    nomeReal: extrairNomeReal(item.replace('.trickplay', ''))
                });
            }
        });

        // Ordenar MP4s pelo número original
        arquivosMP4.sort((a, b) => a.numero - b.numero);

        // Criar um mapa de pastas para busca rápida
        const mapaPastas = new Map();
        pastasTrickplay.forEach(pasta => {
            mapaPastas.set(pasta.nomeReal, pasta);
        });

        console.log(`\n📊 Encontrados:`);
        console.log(`MP4s: ${arquivosMP4.length}`);
        console.log(`Pastas .trickplay: ${pastasTrickplay.length}`);

        console.log('\n🔄 VERIFICANDO ARQUIVOS...');
        console.log('-'.repeat(60));

        let contador = 1;
        let mp4Renomeados = 0;
        let pastasRenomeadas = 0;
        let mp4Ignorados = 0;
        let pastasIgnoradas = 0;

        // Processar MP4s na ordem original dos números
        for (const mp4 of arquivosMP4) {
            const novoNumero = formatarNumero(contador);

            // VERIFICAÇÃO: MP4 já está correto?
            if (arquivoJaEstaCorreto(mp4.nomeOriginal, contador, mp4.nomeReal)) {
                console.log(`⏭️  MP4 já correto: ${mp4.nomeOriginal} (mantido como ${novoNumero} - ${mp4.nomeReal}.mp4)`);
                mp4Ignorados++;
            } else {
                // Renomear MP4
                const novoNomeMP4 = `${novoNumero} - ${mp4.nomeReal}.mp4`;
                const caminhoAntigoMP4 = path.join(caminhoPasta, mp4.nomeOriginal);
                const caminhoNovoMP4 = path.join(caminhoPasta, novoNomeMP4);

                fs.renameSync(caminhoAntigoMP4, caminhoNovoMP4);
                console.log(`✅ MP4: ${mp4.nomeOriginal} → ${novoNomeMP4}`);
                mp4Renomeados++;
            }

            // Procurar pasta correspondente pelo nome real
            const pastaCorrespondente = mapaPastas.get(mp4.nomeReal);

            if (pastaCorrespondente) {
                // VERIFICAÇÃO: Pasta já está correta?
                if (pastaJaEstaCorreta(pastaCorrespondente.nomeOriginal, contador, mp4.nomeReal)) {
                    console.log(`⏭️  Pasta já correta: ${pastaCorrespondente.nomeOriginal} (mantida como ${novoNumero} - ${mp4.nomeReal}.trickplay)`);
                    pastasIgnoradas++;
                } else {
                    // Renomear pasta
                    const novoNomePasta = `${novoNumero} - ${mp4.nomeReal}.trickplay`;
                    const caminhoAntigoPasta = path.join(caminhoPasta, pastaCorrespondente.nomeOriginal);
                    const caminhoNovoPasta = path.join(caminhoPasta, novoNomePasta);

                    fs.renameSync(caminhoAntigoPasta, caminhoNovoPasta);
                    console.log(`✅ Pasta: ${pastaCorrespondente.nomeOriginal} → ${novoNomePasta}`);
                    pastasRenomeadas++;
                }

                // Remover do mapa para não processar novamente
                mapaPastas.delete(mp4.nomeReal);
            } else {
                console.log(`⚠️  MP4 sem pasta: ${mp4.nomeOriginal}`);
            }

            contador++;
        }

        // Verificar pastas que sobraram (sem MP4 correspondente)
        const pastasRestantes = Array.from(mapaPastas.values());
        if (pastasRestantes.length > 0) {
            console.log('\n⚠️  Pastas .trickplay sem MP4 correspondente (NÃO renomeadas):');
            pastasRestantes.forEach(pasta => {
                console.log(`   • ${pasta.nomeOriginal}`);
            });
        }

        // Resumo final
        console.log('\n' + '='.repeat(60));
        console.log('✅ RESUMO FINAL:');
        console.log(`MP4s renomeados: ${mp4Renomeados}`);
        console.log(`MP4s já corretos (ignorados): ${mp4Ignorados}`);
        console.log(`Pastas renomeadas: ${pastasRenomeadas}`);
        console.log(`Pastas já corretas (ignoradas): ${pastasIgnoradas}`);
        console.log(`Pastas ignoradas (sem MP4): ${pastasRestantes.length}`);
        console.log(`\n📊 Total MP4s: ${arquivosMP4.length} | Total pastas: ${pastasTrickplay.length}`);

    } catch (erro) {
        console.error('❌ Erro:', erro.message);
    }
}

// Função de preview (também atualizada para mostrar o que será renomeado)
function previewRenomeacao(caminhoPasta) {
    try {
        console.log('\n📋 PREVIEW DA RENOMEAÇÃO');
        console.log('='.repeat(60));

        const itens = fs.readdirSync(caminhoPasta);
        const arquivosMP4 = [];
        const pastasTrickplay = [];

        itens.forEach(item => {
            const caminhoCompleto = path.join(caminhoPasta, item);
            const stats = fs.statSync(caminhoCompleto);

            if (stats.isFile() && item.toLowerCase().endsWith('.mp4')) {
                const numero = extrairNumeroOriginal(item);
                arquivosMP4.push({
                    nomeOriginal: item,
                    numero: numero,
                    nomeReal: extrairNomeReal(item.replace('.mp4', ''))
                });
            }
            else if (stats.isDirectory() && item.toLowerCase().endsWith('.trickplay')) {
                const numero = extrairNumeroOriginal(item);
                pastasTrickplay.push({
                    nomeOriginal: item,
                    numero: numero,
                    nomeReal: extrairNomeReal(item.replace('.trickplay', ''))
                });
            }
        });

        // Ordenar MP4s pelo número original
        arquivosMP4.sort((a, b) => a.numero - b.numero);

        // Criar mapa de pastas
        const mapaPastas = new Map();
        pastasTrickplay.forEach(pasta => {
            mapaPastas.set(pasta.nomeReal, pasta);
        });

        console.log(`\n📊 Encontrados: ${arquivosMP4.length} MP4s | ${pastasTrickplay.length} pastas`);
        console.log('\nOrdem ORIGINAL dos episódios (baseada nos números):');

        let contador = 1;
        let mp4PrecisaRenomear = 0;
        let pastaPrecisaRenomear = 0;

        for (const mp4 of arquivosMP4) {
            const novoNumero = formatarNumero(contador);
            const pastaCorrespondente = mapaPastas.get(mp4.nomeReal);

            // Verifica se MP4 precisa ser renomeado
            const mp4Correto = arquivoJaEstaCorreto(mp4.nomeOriginal, contador, mp4.nomeReal);
            if (!mp4Correto) mp4PrecisaRenomear++;

            console.log(`\n📌 Episódio ${mp4.numero} → Novo número ${novoNumero}:`);
            console.log(`   MP4: ${mp4.nomeOriginal}`);

            if (mp4Correto) {
                console.log(`   ✅ JÁ CORRETO: ${mp4.nomeOriginal}`);
            } else {
                console.log(`   🔄 SERÁ: ${novoNumero} - ${mp4.nomeReal}.mp4`);
            }

            if (pastaCorrespondente) {
                const pastaCorreta = pastaJaEstaCorreta(pastaCorrespondente.nomeOriginal, contador, mp4.nomeReal);
                if (!pastaCorreta) pastaPrecisaRenomear++;

                console.log(`   Pasta: ${pastaCorrespondente.nomeOriginal}`);
                if (pastaCorreta) {
                    console.log(`   ✅ JÁ CORRETA: ${pastaCorrespondente.nomeOriginal}`);
                } else {
                    console.log(`   🔄 SERÁ: ${novoNumero} - ${mp4.nomeReal}.trickplay`);
                }
            } else {
                console.log(`   ⚠️  Sem pasta .trickplay`);
            }

            contador++;
        }

        // Pastas sem MP4
        const pastasSemMP4 = pastasTrickplay.filter(pasta =>
            !arquivosMP4.some(mp4 => mp4.nomeReal === pasta.nomeReal)
        );

        if (pastasSemMP4.length > 0) {
            console.log('\n📌 Pastas sem MP4 correspondente (NÃO serão renomeadas):');
            pastasSemMP4.forEach(pasta => {
                console.log(`   • ${pasta.nomeOriginal}`);
            });
        }

        console.log('\n' + '='.repeat(60));
        console.log('📊 RESUMO DO PREVIEW:');
        console.log(`MP4s que precisam ser renomeados: ${mp4PrecisaRenomear}`);
        console.log(`Pastas que precisam ser renomeadas: ${pastaPrecisaRenomear}`);
        console.log(`MP4s já corretos: ${arquivosMP4.length - mp4PrecisaRenomear}`);
        console.log(`Pastas já corretas: ${pastasTrickplay.length - pastasSemMP4.length - pastaPrecisaRenomear}`);

    } catch (erro) {
        console.error('❌ Erro no preview:', erro.message);
    }
}

// === CONFIGURAÇÃO ===
const caminhoDaPasta = './'; // Mude para o caminho da sua pasta

// ESCOLHA O MODO:
// 1. Preview (recomendado primeiro)
// previewRenomeacao(caminhoDaPasta);

// 2. Renomear (descomente a linha abaixo quando estiver pronto)
renomearArquivos(caminhoDaPasta);