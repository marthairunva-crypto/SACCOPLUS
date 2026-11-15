# SACCOPLUS Proxy Server

Secure proxy server for MarzPay mobile money transactions, airtime, data bundles, and bill payments.

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment Variables

Copy the example file and fill in your credentials:

```bash
cp .env.example .env
```

Then edit `.env` and add your credentials:

- **MARZPAY_AUTH**: Your MarzPay API credentials (Base64 encoded)
  - Get from: https://wallet.wearemarz.com/dashboard/settings/api
  - Format: `base64encode(API_KEY:API_SECRET)`
  - The dashboard shows you the already-encoded "Authorization: Basic" header - copy that value

- **GROQ_API_KEY**: Your Groq API key (for AI features)
  - Get from: https://console.groq.com/keys

- **PROXY_KEY**: Secret key used by your apps to authenticate with this proxy
  - Default: `saccoplus_pro_2025_proxy_key`
  - Change this to your own secret in production

### 3. Run Locally

Development mode (auto-restart on changes):
```bash
npm run dev
```

Production mode:
```bash
npm start
```

### 4. Deploy to Render.com

1. Create a new **Web Service** on Render
2. Connect your GitHub repo
3. Set **Root Directory**: `proxy`
4. Set **Build Command**: `npm install`
5. Set **Start Command**: `npm start`
6. Add environment variables in Render dashboard:
   - `MARZPAY_AUTH`
   - `GROQ_API_KEY`
   - `PROXY_KEY`
7. Deploy!

Your proxy URL will be: `https://your-app-name.onrender.com`

## API Endpoints

### Mobile Money

- `POST /collect` - Initiate money collection (deposit)
- `POST /withdraw` - Send money (withdrawal)
- `GET /status/:uuid` - Check transaction status
- `GET /withdraw-status/:uuid` - Check withdrawal status

### Airtime & Data

- `POST /marzpay/airtime/providers` - Get airtime providers
- `POST /marzpay/airtime/purchase` - Buy airtime
- `POST /marzpay/data/bundles` - Get data bundles
- `POST /marzpay/data/purchase` - Buy data

### Bill Payments

- `GET /marzpay/bill-payment/dstv/packages` - Get DStv packages
- `POST /marzpay/bill-payment/dstv/pay` - Pay DStv
- Similar endpoints for GOtv, StarTimes, UMEME, NWSC

### Generic Proxy

- `GET /marzpay/proxy?path=...` - Relay any MarzPay API call

## Security

- All requests must include `X-Proxy-Key` header matching your `PROXY_KEY`
- Never commit `.env` file to git (it's in `.gitignore`)
- Rotate your API keys periodically
- Use HTTPS in production

## Testing

Health check:
```bash
curl http://localhost:3000/health
```

Test collection:
```bash
curl -X POST http://localhost:3000/collect \
  -H "Content-Type: application/json" \
  -H "X-Proxy-Key: saccoplus_pro_2025_proxy_key" \
  -d '{
    "amount": 1000,
    "phone_number": "+256712345678",
    "reference": "test-ref-123",
    "country": "UG"
  }'
```

## Troubleshooting

**"Unauthorized" errors**: Check that your `X-Proxy-Key` header matches `PROXY_KEY` in `.env`

**"Invalid credentials" from MarzPay**: Verify your `MARZPAY_AUTH` is correct and not expired

**SMS not sending**: Check Groq API key and credits

## Support

For issues or questions, contact the development team.
