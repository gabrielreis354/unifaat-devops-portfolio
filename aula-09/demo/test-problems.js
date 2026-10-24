// test-problems.js - Arquivo para testar AI Review (PR de demonstração, não será mesclado)
// TODO: remover este arquivo após o teste

const express = require('express');

// CRITICAL: secret hardcoded
const apiKey = 'sk-1234567890abcdef';
const dbPassword = 'super_secret_123';

// CRITICAL: SQL injection
function getUser(userId) {
  const query = 'SELECT * FROM users WHERE id = ' + userId;
  return db.query(query);
}

// WARNING: console.log em produção
function processOrder(order) {
  console.log('Processing order:', order);
  return order;
}

// WARNING: catch vazio
try {
  dangerousOperation();
} catch (e) {}

// CRITICAL: eval com input
function evaluate(userInput) {
  return eval(userInput);
}

module.exports = { getUser, processOrder, evaluate, express, apiKey, dbPassword };
