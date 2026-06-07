'use strict';

const path = require('path');
const express = require('express');
const { saveSubmission } = require('./db');

const REQUIRED_FIELDS = [
  'fullName',
  'dateOfBirth',
  'address',
  'nationality',
  'occupation',
];

const FIELD_LABELS = {
  fullName: 'Name',
  dateOfBirth: 'Date of birth',
  address: 'Address',
  nationality: 'Nationality',
  occupation: 'Occupation',
};

// Factory rather than a started server, so tests can drive it with supertest
// without binding a port.
function createApp() {
  const app = express();

  app.use(express.urlencoded({ extended: true }));
  app.use(express.json());

  app.use(express.static(path.join(__dirname, '..', 'public')));

  // Hit by the deploy smoke test.
  app.get('/health', (req, res) => res.json({ status: 'ok' }));

  app.post('/submit', async (req, res) => {
    const body = req.body || {};
    const data = {};
    const missing = [];

    for (const field of REQUIRED_FIELDS) {
      const value = typeof body[field] === 'string' ? body[field].trim() : '';
      if (!value) missing.push(field);
      data[field] = value;
    }

    if (missing.length > 0) {
      return res.status(400).send(renderError(missing));
    }

    try {
      const saved = await saveSubmission(data);
      return res.status(201).send(renderSuccess(saved));
    } catch (err) {
      // Log the detail, send the user something generic.
      console.error('Failed to save submission:', err);
      return res.status(500).send(renderServerError());
    }
  });

  return app;
}

// HTML kept inline to avoid pulling in a template engine.

function page(title, bodyHtml) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${title}</title>
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <main class="card">
    ${bodyHtml}
  </main>
</body>
</html>`;
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function renderSuccess(item) {
  const rows = REQUIRED_FIELDS
    .map((f) => `<tr><th>${FIELD_LABELS[f]}</th><td>${escapeHtml(item[f])}</td></tr>`)
    .join('\n');

  return page('Submission received', `
    <h1>Thank you</h1>
    <p>Your details have been submitted successfully.</p>
    <table class="summary">${rows}</table>
    <p><a class="button" href="/">Submit another</a></p>
  `);
}

function renderError(missingFields) {
  const list = missingFields
    .map((f) => `<li>${FIELD_LABELS[f] || f}</li>`)
    .join('\n');

  return page('Missing information', `
    <h1>Some fields are missing</h1>
    <p>Please go back and complete the following:</p>
    <ul class="errors">${list}</ul>
    <p><a class="button" href="/">Back to form</a></p>
  `);
}

function renderServerError() {
  return page('Something went wrong', `
    <h1>Something went wrong</h1>
    <p>We couldn't save your details right now. Please try again later.</p>
    <p><a class="button" href="/">Back to form</a></p>
  `);
}

module.exports = { createApp, REQUIRED_FIELDS, FIELD_LABELS };
