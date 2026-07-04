'use strict';

const request = require('supertest');

// Mock the DynamoDB layer so tests never touch AWS.
jest.mock('../src/db', () => ({
  saveSubmission: jest.fn(),
}));

const { saveSubmission } = require('../src/db');
const { createApp } = require('../src/app');

const app = createApp();

const validSubmission = {
  fullName: 'Jane Doe',
  dateOfBirth: '1990-05-01',
  address: '123 Example Street, Glasgow',
  nationality: 'British',
  occupation: 'Engineer',
};

beforeEach(() => {
  jest.clearAllMocks();
});

describe('GET /health', () => {
  it('returns ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(999);
    expect(res.body).toEqual({ status: 'ok' });
  });
});

describe('GET /', () => {
  it('serves the form page', async () => {
    const res = await request(app).get('/');
    expect(res.status).toBe(200);
    expect(res.text).toContain('<form');
    expect(res.text).toContain('name="fullName"');
  });
});

describe('POST /submit', () => {
  it('saves a valid submission and returns 201', async () => {
    saveSubmission.mockResolvedValue({ id: 'abc-123', ...validSubmission });

    const res = await request(app)
      .post('/submit')
      .type('form')
      .send(validSubmission);

    expect(res.status).toBe(201);
    expect(saveSubmission).toHaveBeenCalledTimes(1);
    expect(saveSubmission).toHaveBeenCalledWith(validSubmission);
    expect(res.text).toContain('Thank you');
  });

  it('rejects a submission with missing fields and does not call the DB', async () => {
    const res = await request(app)
      .post('/submit')
      .type('form')
      .send({ fullName: 'Jane Doe' }); // everything else missing

    expect(res.status).toBe(400);
    expect(saveSubmission).not.toHaveBeenCalled();
    expect(res.text).toContain('missing');
  });

  it('trims whitespace and rejects fields that are only spaces', async () => {
    const res = await request(app)
      .post('/submit')
      .type('form')
      .send({ ...validSubmission, occupation: '   ' });

    expect(res.status).toBe(400);
    expect(saveSubmission).not.toHaveBeenCalled();
  });

  it('returns 500 when the database fails', async () => {
    saveSubmission.mockRejectedValue(new Error('DynamoDB unavailable'));

    const res = await request(app)
      .post('/submit')
      .type('form')
      .send(validSubmission);

    expect(res.status).toBe(500);
    expect(res.text).toContain('went wrong');
  });
});
