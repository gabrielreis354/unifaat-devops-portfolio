const fs = require('fs');

// ============================================
// AI Review da TechNova
// ============================================
// Analisa as linhas ADICIONADAS de um diff e classifica os achados por severidade.
// Nesta versão a "IA" é baseada em regras (pattern matching). O prompt que seria
// enviado a um modelo (Bedrock) está documentado em aula-09/ia-cicd-analise.md.

const SEVERITY = {
  CRITICAL: '🔴 CRITICAL',
  WARNING: '🟡 WARNING',
  INFO: '🔵 INFO'
};

const REPORT_MARKER = '## 🤖 AI Code Review - TechNova';

// Arquivos que não são código de produção: ignorados para não gerar falso positivo
// (inclui o próprio script e seus testes, que citam os padrões procurados).
const IGNORED_FILES = [
  /^\.github\/scripts\/ai-review(\.test)?\.js$/,
  /\.md$/i,
  /(^|\/)package-lock\.json$/
];

const CODE_FILES = /\.(js|jsx|ts|tsx|mjs|cjs)$/;

// Regras sem a flag /g: um achado por regra e por linha, sem estado entre chamadas.
const RULES = [
  {
    pattern: /(password|passwd|secret|api[_-]?key|token)\w*\s*[:=]\s*['"][^'"]{4,}['"]/i,
    message: 'Possível secret/credencial hardcoded',
    severity: SEVERITY.CRITICAL
  },
  {
    pattern: /\beval\s*\(/,
    message: 'Uso de eval() - risco de code injection',
    severity: SEVERITY.CRITICAL
  },
  {
    pattern: /\bexec(Sync)?\s*\(\s*`[^`]*\$\{/,
    message: 'Possível command injection via template literal',
    severity: SEVERITY.CRITICAL
  },
  {
    pattern: /['"`]\s*(SELECT|INSERT|UPDATE|DELETE)\b[^'"`]*(['"]\s*\+|\$\{)/i,
    message: 'Possível SQL injection - use queries parametrizadas',
    severity: SEVERITY.CRITICAL
  },
  {
    pattern: /AKIA[0-9A-Z]{16}/,
    message: 'Possível AWS Access Key no código',
    severity: SEVERITY.CRITICAL
  },
  {
    pattern: /BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY/,
    message: 'Chave privada no código',
    severity: SEVERITY.CRITICAL
  },
  {
    pattern: /\bconsole\.(log|debug|info)\s*\(/,
    message: 'console.log em código de produção (remover ou usar logger)',
    severity: SEVERITY.WARNING,
    onlyFiles: CODE_FILES
  },
  {
    pattern: /catch\s*(\(\s*\w*\s*\))?\s*\{\s*\}/,
    message: 'Catch vazio - erros silenciados podem esconder bugs',
    severity: SEVERITY.WARNING,
    onlyFiles: CODE_FILES
  },
  {
    pattern: /0\.0\.0\.0/,
    message: 'Binding em 0.0.0.0 - verificar se é intencional em produção',
    severity: SEVERITY.WARNING
  },
  {
    pattern: /['"`]http:\/\/(?!localhost|127\.0\.0\.1)[^'"`\s]+/,
    message: 'URL http:// (sem TLS) hardcoded',
    severity: SEVERITY.WARNING
  },
  {
    pattern: /\b(TODO|FIXME|HACK|XXX)\b/,
    message: 'Comentário TODO/FIXME - resolver antes do merge',
    severity: SEVERITY.INFO
  }
];

function isIgnored(file) {
  return IGNORED_FILES.some((re) => re.test(file));
}

function analyzeDiff(diffContent) {
  const findings = [];
  let currentFile = '';
  let newLine = 0;

  for (const line of diffContent.split('\n')) {
    if (line.startsWith('+++ ')) {
      currentFile = line.replace(/^\+\+\+ (b\/)?/, '');
      continue;
    }

    const hunk = line.match(/^@@ -\d+(?:,\d+)? \+(\d+)/);
    if (hunk) {
      newLine = parseInt(hunk[1], 10);
      continue;
    }

    if (line.startsWith('-') || line.startsWith('\\')) continue;

    const isAdded = line.startsWith('+');
    if (isAdded && !isIgnored(currentFile)) {
      const code = line.substring(1);
      for (const rule of RULES) {
        if (rule.onlyFiles && !rule.onlyFiles.test(currentFile)) continue;
        if (rule.pattern.test(code)) {
          findings.push({
            file: currentFile,
            line: newLine,
            code: code.trim(),
            message: rule.message,
            severity: rule.severity
          });
        }
      }
    }
    newLine++;
  }

  return findings;
}

function cell(text, max) {
  const short = text.length > max ? text.substring(0, max - 3) + '...' : text;
  return short.replace(/\|/g, '\\|').replace(/`/g, "'");
}

function generateReport(findings) {
  if (findings.length === 0) {
    return `${REPORT_MARKER}

✅ **Nenhum problema encontrado!**

O código alterado neste PR passou pela análise automatizada sem achados.
Lembre-se: este review automático complementa, mas não substitui, o review humano.

---
*Review automatizado por AI Pipeline - TechNova DevOps*`;
  }

  const count = (severity) => findings.filter((f) => f.severity === severity).length;
  const criticals = count(SEVERITY.CRITICAL);

  let report = `${REPORT_MARKER}\n\n`;
  report += `**Resumo:** ${findings.length} achado(s) encontrado(s)\n`;
  report += `- ${SEVERITY.CRITICAL}: ${criticals}\n`;
  report += `- ${SEVERITY.WARNING}: ${count(SEVERITY.WARNING)}\n`;
  report += `- ${SEVERITY.INFO}: ${count(SEVERITY.INFO)}\n\n`;

  if (criticals > 0) {
    report += `> ⛔ **Este PR tem achados CRITICAL que devem ser corrigidos antes do merge.**\n\n`;
  }

  report += `### Achados Detalhados\n\n`;
  report += `| Severidade | Arquivo | Linha | Problema | Código |\n`;
  report += `|:----------:|---------|:-----:|----------|--------|\n`;
  for (const f of findings) {
    const file = f.file.length > 40 ? '...' + f.file.slice(-37) : f.file;
    report += `| ${f.severity} | \`${file}\` | ${f.line} | ${f.message} | \`${cell(f.code, 60)}\` |\n`;
  }

  report += `\n---\n`;
  report += `*Review automatizado por AI Pipeline - TechNova DevOps*\n`;
  report += `*⚠️ Falsos positivos são possíveis. Avalie cada achado criticamente.*`;
  return report;
}

function setOutput(name, value) {
  if (process.env.GITHUB_OUTPUT) {
    fs.appendFileSync(process.env.GITHUB_OUTPUT, `${name}=${value}\n`);
  }
}

// ============================================
// Execução principal (só quando chamado direto)
// ============================================
function main() {
  const diffFile = process.env.DIFF_FILE || '/tmp/pr-diff.txt';
  const resultFile = process.env.RESULT_FILE || '/tmp/ai-review-result.md';

  const findings = analyzeDiff(fs.readFileSync(diffFile, 'utf8'));
  const report = generateReport(findings);
  fs.writeFileSync(resultFile, report);

  const hasCritical = findings.some((f) => f.severity === SEVERITY.CRITICAL);
  setOutput('critical', hasCritical);
  setOutput('total', findings.length);

  console.log(report);
  console.log(`\nAnálise completa: ${findings.length} achado(s); CRITICAL: ${hasCritical}`);
  // O bloqueio do PR (exit 1) fica em um step próprio do workflow, depois de postar o comentário.
}

if (require.main === module) {
  try {
    main();
  } catch (error) {
    // Fail Fast: se a análise não rodou, o check não pode ficar verde.
    console.error('Erro na análise:', error.message);
    process.exit(1);
  }
}

module.exports = { analyzeDiff, generateReport, SEVERITY, REPORT_MARKER };
