// PriceShield Real-Time Event Stream Broadcaster (SSE)
// Delivers live real-time updates to mobile apps and admin dashboard clients

const clients = new Set();

/**
 * Register a client for Server-Sent Events
 * @param {import('express').Request} req
 * @param {import('express').Response} res
 * @param {object} options
 * @param {string|null} options.userId
 * @param {boolean} options.isAdmin
 */
export function registerEventClient(req, res, { userId = null, isAdmin = false } = {}) {
  const headers = {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache, no-transform',
    'Connection': 'keep-alive',
    'X-Accel-Buffering': 'no',
  };

  if (req.headers.origin) {
    headers['Access-Control-Allow-Origin'] = req.headers.origin;
    headers['Access-Control-Allow-Credentials'] = 'true';
  } else {
    headers['Access-Control-Allow-Origin'] = '*';
  }

  // Set headers for Server-Sent Events
  res.writeHead(200, headers);

  const client = {
    id: `client-${Date.now()}-${Math.random().toString(36).substring(2, 8)}`,
    res,
    userId,
    isAdmin,
  };

  clients.add(client);

  // Send initial handshake
  res.write(`event: connected\ndata: ${JSON.stringify({ status: 'connected', clientId: client.id, timestamp: new Date().toISOString() })}\n\n`);

  // Heartbeat ping every 25s to keep connections alive across NAT/proxies
  const heartbeat = setInterval(() => {
    try {
      res.write(': keepalive\n\n');
    } catch (_) {
      clearInterval(heartbeat);
      clients.delete(client);
    }
  }, 25000);

  req.on('close', () => {
    clearInterval(heartbeat);
    clients.delete(client);
  });

  return client;
}

/**
 * Broadcast an event to connected clients
 * @param {string} eventName
 * @param {object} payload
 * @param {object} [filter]
 * @param {string} [filter.userId]
 */
export function broadcastEvent(eventName, payload, { userId = null } = {}) {
  const message = `event: ${eventName}\ndata: ${JSON.stringify(payload)}\n\n`;

  for (const client of clients) {
    try {
      // Admins receive all events. Normal clients receive events matching their userId or broadcast events (no target userId)
      if (client.isAdmin || !userId || !client.userId || client.userId === userId) {
        client.res.write(message);
      }
    } catch (_) {
      clients.delete(client);
    }
  }
}

/**
 * Broadcast a complaint update event
 * @param {object} complaint
 */
export function broadcastComplaintUpdated(complaint) {
  if (!complaint) return;
  const isBoosted = Array.isArray(complaint.riskFlags) &&
    (complaint.riskFlags.includes('PRIORITY_BOOST_24H') || complaint.riskFlags.includes('BOOSTED'));

  broadcastEvent('complaint_updated', {
    type: 'COMPLAINT_UPDATED',
    complaintId: complaint.id,
    userId: complaint.userId,
    status: complaint.status,
    confidenceLevel: complaint.confidenceLevel,
    isPublicEligible: complaint.isPublicEligible,
    moderationNotes: complaint.moderationNotes,
    merchantResponse: complaint.merchantResponse,
    isBoosted,
    boostTier: isBoosted ? 'PRIORITY_24H' : 'STANDARD',
    updatedAt: complaint.updatedAt || new Date().toISOString(),
    complaint,
  }, { userId: complaint.userId });
}

/**
 * Get count of active SSE subscribers
 */
export function getActiveClientsCount() {
  return clients.size;
}
