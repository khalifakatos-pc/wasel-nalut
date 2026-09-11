# 🚀 Wasel Nalut: Production Deployment, DevOps & Security Specifications
# Document: 07_PRODUCTION_DEPLOYMENT_AND_DEVOPS.md

This specification details cloud provisioning, containerization, static routing, security hardening, and deployment on **Render** for **Wasel Nalut**.

---

## 1. Live Production Topology on Render

- **Production Service URL**: `https://wasel-nalut.onrender.com`
- **Render Service ID**: `srv-dah70u2jnfac738j2e9g`
- **Repository**: `https://github.com/khalifakatos-pc/wasel-nalut.git`
- **Branch**: `main` (auto-deploys on push)
- **Runtime**: Node.js 18+ / 20+

### Production Endpoints:
| Route | Platform Component | Description |
|:---|:---|:---|
| `/` | Landing / API Gateway Status | Returns platform status, version, and endpoints overview |
| `/app/` | Customer Super-App (Flutter Web) | Compiled release of `flutter_mobile_app` |
| `/merchant` | Merchant Web KDS Portal | Kitchen Display System with multi-tenant store isolation |
| `/admin` | Operations & Dispatch Hub | Live fleet map, daily Z-audit, dispute room (PIN: 7788) |
| `/api/v1/*` | REST API | Stores, catalog, checkout, orders, accounting |
| `/socket.io/*` | WebSocket Fleet Telemetry | Real-time GPS broadcasting & order room notifications |

---

## 2. Server Configuration (`backend/server.js`)

The Express server serves both the REST API and the static web frontends:

```javascript
// Static Route Mapping
app.use('/app', express.static(path.join(__dirname, 'public', 'app')));
app.use('/merchant', express.static(path.join(__dirname, 'public', 'merchant')));
app.use('/admin', express.static(path.join(__dirname, 'public', 'admin')));
```

### Environment Variables:
```env
PORT=3000
NODE_ENV=production
JWT_SECRET=wasel_nalut_secure_jwt_token_2026_super_key
MASTER_ADMIN_PIN=7788
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
```

---

## 3. Docker Containerization (`Dockerfile`)

```dockerfile
# Multi-stage Dockerfile
FROM node:20-alpine AS backend-builder
WORKDIR /app

COPY backend/package*.json ./
RUN npm ci --only=production

COPY backend/ ./

EXPOSE 3000
CMD ["node", "server.js"]
```

---

## 4. Full Release Pipeline Execution

To rebuild and deploy the entire platform from terminal:

```powershell
# Step 1: Verify all 4 Flutter apps have 0 errors
cd C:\Users\kalifa\super_app_delivery\flutter_mobile_app ; flutter analyze
cd C:\Users\kalifa\super_app_delivery\flutter_driver_app ; flutter analyze
cd C:\Users\kalifa\super_app_delivery\flutter_merchant_app ; flutter analyze
cd C:\Users\kalifa\super_app_delivery\flutter_admin_app ; flutter analyze

# Step 2: Build Flutter Web release
cd C:\Users\kalifa\super_app_delivery\flutter_mobile_app
flutter build web --release --base-href /app/
Copy-Item -Path "build\web\*" -Destination "..\backend\public\app\" -Recurse -Force

# Step 3: Git Commit and Push to trigger Render Auto-Deploy
cd C:\Users\kalifa\super_app_delivery
git add .
git commit -m "release: deploy updated Wasel Nalut production bundle"
git push origin main
```

---

## 5. Google Play Compliance Checklist

All 4 Android apps comply with Google Play guidelines:
1. **Target SDK**: Android 14 (API 34) / Android 15 (API 35).
2. **Foreground Service Types**: `location` explicitly declared in `AndroidManifest.xml` for `flutter_driver_app`.
3. **Privacy Policy**: Dedicated legal audit file `GOOGLE_PLAY_COMPLIANCE_AND_LEGAL_AUDIT.md` included in repository root.
4. **App Icons**: High-resolution icons created and configured across all mipmap densities using `apply_app_icons.ps1`.
