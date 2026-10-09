import path from 'node:path';

export type AppConfig = {
  isProd: boolean;
  port: number;
  databaseUrl: string | null;
  dataDir: string;
  jwtAccessSecret: string;
  jwtRefreshSecret: string;
  mediaSecret: string;
  uploadDir: string;
  publicBaseUrl: string;
  devOtp: string | null;
  runWorker: boolean;
  corsOrigin: string;
  smartSwmConnection: string | null;
  faceModels: string | null;
};

export function loadConfig(overrides: Partial<AppConfig> = {}): AppConfig {
  const isProd = (process.env.NODE_ENV ?? 'development') === 'production';
  const config: AppConfig = {
    isProd,
    port: Number(process.env.PORT ?? 4000),
    databaseUrl: process.env.DATABASE_URL?.trim() || null,
    dataDir: path.resolve(process.env.DATA_DIR ?? '.data/pg'),
    jwtAccessSecret: process.env.JWT_ACCESS_SECRET ?? 'dev-access-secret-change-me',
    jwtRefreshSecret: process.env.JWT_REFRESH_SECRET ?? 'dev-refresh-secret-change-me',
    mediaSecret: process.env.MEDIA_SECRET ?? 'dev-media-secret-change-me',
    uploadDir: path.resolve(process.env.UPLOAD_DIR ?? 'uploads'),
    publicBaseUrl: process.env.PUBLIC_BASE_URL ?? 'http://localhost:4000',
    devOtp: isProd ? null : (process.env.OTP_DEV_CODE ?? '123456'),
    runWorker: (process.env.RUN_WORKER ?? 'true') !== 'false',
    corsOrigin: process.env.CORS_ORIGIN ?? '*',
    smartSwmConnection: process.env.SMARTSWM_CONNECTION?.trim() || null,
    faceModels: process.env.FACE_MODELS?.trim() || null,
  };
  if (isProd) {
    for (const key of ['jwtAccessSecret', 'jwtRefreshSecret', 'mediaSecret'] as const) {
      if (config[key].startsWith('dev-') || config[key].startsWith('change-me')) {
        throw new Error(`${key} must be set to a real secret in production.`);
      }
    }
    if (config.devOtp) throw new Error('OTP_DEV_CODE cannot be set in production.');
  }
  return { ...config, ...overrides };
}
