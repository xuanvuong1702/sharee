import http from 'http';

const server = http.createServer((req, res) => {
  let body = '';
  req.on('data', (chunk) => (body += chunk));
  req.on('end', () => {
    res.setHeader('Content-Type', 'application/json');
    if (req.method === 'POST' && req.url === '/v2/payment-requests') {
      const input = JSON.parse(body || '{}');
      res.end(JSON.stringify({
        code: '00',
        desc: 'success',
        data: {
          bin: '970422',
          accountNumber: '0000000001',
          accountName: 'SHAREE TEST',
          amount: input.amount,
          description: input.description,
          orderCode: input.orderCode,
          currency: 'VND',
          paymentLinkId: `plink_${input.orderCode}`,
          status: 'PENDING',
          checkoutUrl: `http://localhost:19090/checkout/${input.orderCode}`,
          qrCode: `00020101021238570010A000000727012700069704220113000000000010208QRIBFTTA5303840540${input.amount}5802VN6304TEST`,
        },
      }));
      return;
    }
    res.statusCode = 200;
    res.end(JSON.stringify({ status: 'ok' }));
  });
});
server.listen(19090, () => console.log('fake payos on 19090'));
