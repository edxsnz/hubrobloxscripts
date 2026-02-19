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

        console.log('\n🔄 RENOMEANDO...');
        console.log('-'.repeat(60));

        let contador = 1;
        const mp4Renomeados = [];
        const pastasRenomeadas = [];

        // Processar MP4s na ordem original dos números
        for (const mp4 of arquivosMP4) {
            const novoNumero = formatarNumero(contador);
            const novoNomeMP4 = `${novoNumero} - ${mp4.nomeReal}.mp4`;

            // Renomear MP4
            const caminhoAntigoMP4 = path.join(caminhoPasta, mp4.nomeOriginal);
            const caminhoNovoMP4 = path.join(caminhoPasta, novoNomeMP4);

            fs.renameSync(caminhoAntigoMP4, caminhoNovoMP4);
            console.log(`✅ MP4: ${mp4.nomeOriginal} → ${novoNomeMP4}`);
            mp4Renomeados.push(mp4.nomeOriginal);

            // Procurar pasta correspondente pelo nome real
            const pastaCorrespondente = mapaPastas.get(mp4.nomeReal);

            if (pastaCorrespondente) {
                const novoNomePasta = `${novoNumero} - ${mp4.nomeReal}.trickplay`;
                const caminhoAntigoPasta = path.join(caminhoPasta, pastaCorrespondente.nomeOriginal);
                const caminhoNovoPasta = path.join(caminhoPasta, novoNomePasta);

                fs.renameSync(caminhoAntigoPasta, caminhoNovoPasta);
                console.log(`✅ Pasta: ${pastaCorrespondente.nomeOriginal} → ${novoNomePasta}`);
                pastasRenomeadas.push(pastaCorrespondente.nomeOriginal);

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
        console.log(`MP4s renomeados: ${mp4Renomeados.length}`);
        console.log(`Pastas renomeadas: ${pastasRenomeadas.length}`);
        console.log(`Pastas ignoradas (sem MP4): ${pastasRestantes.length}`);

    } catch (erro) {
        console.error('❌ Erro:', erro.message);
    }
}

// Função de preview
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
        for (const mp4 of arquivosMP4) {
            const novoNumero = formatarNumero(contador);
            const pastaCorrespondente = mapaPastas.get(mp4.nomeReal);

            console.log(`\n📌 Episódio ${mp4.numero} → Novo número ${novoNumero}:`);
            console.log(`   MP4: ${mp4.nomeOriginal}`);
            console.log(`   → ${novoNumero} - ${mp4.nomeReal}.mp4`);

            if (pastaCorrespondente) {
                console.log(`   Pasta: ${pastaCorrespondente.nomeOriginal}`);
                console.log(`   → ${novoNumero} - ${mp4.nomeReal}.trickplay`);
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