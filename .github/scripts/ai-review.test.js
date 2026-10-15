const test = require('node:test');
const assert = require('node:assert');
const { analyzeDiff, generateReport, SEVERITY } = require('./ai-review.js');

// Monta um diff mínimo de um arquivo, com as linhas adicionadas a partir da linha 10.
function diffOf(file, ...added) {
  return [
    `diff --git a/${file} b/${file}`,
    `--- a/${file}`,
    `+++ b/${file}`,
    `@@ -9,1 +10,${added.length} @@`,
    ...added.map((l) => `+${l}`)
  ].join('\n');
}

const cases = [
  ['secret hardcoded', "const apiKey = 'sk-1234567890abcdef';", SEVERITY.CRITICAL],
  ['password hardcoded', "const dbPassword = 'super_secret_123';", SEVERITY.CRITICAL],
  ['eval()', 'return eval(userInput);', SEVERITY.CRITICAL],
  ['command injection', 'exec(`ls ${dir}`);', SEVERITY.CRITICAL],
  ['SQL concatenado', "const q = 'SELECT * FROM users WHERE id = ' + userId;", SEVERITY.CRITICAL],
  ['SQL com template', 'const q = `DELETE FROM orders WHERE id = ${id}`;', SEVERITY.CRITICAL],
  ['chave AWS', "const k = 'AKIAABCDEFGHIJKLMNOP';", SEVERITY.CRITICAL],
  ['chave privada', '-----BEGIN RSA PRIVATE KEY-----', SEVERITY.CRITICAL],
  ['console.log', "console.log('debug', order);", SEVERITY.WARNING],
  ['catch vazio', 'try { run(); } catch (e) {}', SEVERITY.WARNING],
  ['bind 0.0.0.0', "app.listen(3000, '0.0.0.0');", SEVERITY.WARNING],
  ['URL http hardcoded', "const url = 'http://api.externa.com/v1';", SEVERITY.WARNING],
  ['TODO', '// TODO: implementar cache', SEVERITY.INFO]
];

for (const [name, code, severity] of cases) {
  test(`detecta ${name} como ${severity}`, () => {
    const findings = analyzeDiff(diffOf('server.js', code));
    assert.strictEqual(findings.length, 1, JSON.stringify(findings));
    assert.strictEqual(findings[0].severity, severity);
  });
}

test('diff limpo não gera achados', () => {
  const findings = analyzeDiff(diffOf('server.js', "const x = 1;", "console.error('falha');", "fetch('http://localhost:3000');"));
  assert.deepStrictEqual(findings, []);
});

test('informa a linha real do arquivo (não a do diff)', () => {
  const findings = analyzeDiff(diffOf('server.js', 'const a = 1;', 'return eval(x);'));
  assert.strictEqual(findings[0].file, 'server.js');
  assert.strictEqual(findings[0].line, 11);
});

test('linhas de contexto avançam a numeração; linhas removidas não', () => {
  const diff = [
    '+++ b/server.js',
    '@@ -1,3 +5,3 @@',
    ' contexto',
    '-linha removida com eval(x)',
    '+return eval(y);'
  ].join('\n');
  assert.strictEqual(analyzeDiff(diff)[0].line, 6);
});

test('ignora linhas removidas e cabeçalhos', () => {
  const diff = ['+++ b/server.js', '@@ -1,1 +1,0 @@', '-return eval(x);'].join('\n');
  assert.deepStrictEqual(analyzeDiff(diff), []);
});

test('mesma regra pode repetir em linhas diferentes e mantém um achado por regra/linha', () => {
  const findings = analyzeDiff(diffOf('a.js', 'eval(a); eval(b);', 'eval(c);'));
  assert.strictEqual(findings.length, 2);
});

for (const file of ['.github/scripts/ai-review.js', '.github/scripts/ai-review.test.js', 'README.md', 'aula-09/ia-cicd-analise.md', 'package-lock.json']) {
  test(`ignora arquivo ${file}`, () => {
    assert.deepStrictEqual(analyzeDiff(diffOf(file, 'return eval(x);')), []);
  });
}

test('relatório sem achados é positivo e avisa que não substitui o humano', () => {
  const report = generateReport([]);
  assert.match(report, /## 🤖 AI Code Review - TechNova/);
  assert.match(report, /Nenhum problema encontrado/);
  assert.match(report, /não substitui/);
});

test('relatório com achados traz resumo, aviso de bloqueio e tabela', () => {
  const findings = analyzeDiff(diffOf('server.js', 'return eval(x);', "console.log('a');", '// TODO: x'));
  const report = generateReport(findings);
  assert.match(report, /3 achado\(s\)/);
  assert.match(report, /CRITICAL.*: 1/);
  assert.match(report, /WARNING.*: 1/);
  assert.match(report, /INFO.*: 1/);
  assert.match(report, /corrigidos antes do merge/);
  assert.match(report, /\| Severidade \| Arquivo \| Linha \| Problema \| Código \|/);
  assert.match(report, /`server\.js`/);
});

test('relatório só com WARNING/INFO não menciona bloqueio', () => {
  const report = generateReport(analyzeDiff(diffOf('server.js', "console.log('a');")));
  assert.doesNotMatch(report, /corrigidos antes do merge/);
});

test('o código exibido escapa pipes e crases para não quebrar a tabela', () => {
  const report = generateReport(analyzeDiff(diffOf('server.js', "const a = x | y; eval(`z`);")));
  assert.match(report, /x \\\| y/);
  assert.doesNotMatch(report, /eval\(`z`\)/);
});
