// test-problems.js - Arquivo para testar AI Review (PR de demonstração, não será mesclado)
// TODO: remover este arquivo após o teste

const express = require('express');

// WARNING: console.log em produção
function processOrder(order) {
  console.log('Processing order:', order);
  return order;
}

// WARNING: catch vazio
try {
  dangerousOperation();
} catch (e) {}

module.exports = { processOrder, express };
