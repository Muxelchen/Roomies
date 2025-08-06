import jwt from 'jsonwebtoken';
import { logger } from '@/utils/logger';

const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

export interface JWTPayload {
  userId: string;
  email: string;
  householdId?: string;
  role?: string;
}

export function generateToken(payload: JWTPayload): string {
  try {
    return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN } as jwt.SignOptions);
  } catch (error) {
    logger.error('JWT generation failed:', error);
    throw new Error('Token generation failed');
  }
}

export function verifyToken(token: string): JWTPayload {
  try {
    return jwt.verify(token, JWT_SECRET) as JWTPayload;
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      throw new Error('Token expired');
    } else if (error instanceof jwt.JsonWebTokenError) {
      throw new Error('Invalid token');
    } else {
      logger.error('JWT verification failed:', error);
      throw new Error('Token verification failed');
    }
  }
}

export function refreshToken(token: string): string | null {
  try {
    const payload = jwt.verify(token, JWT_SECRET, { ignoreExpiration: true }) as JWTPayload;
    
    // Remove jwt issued/expired fields to avoid conflicts
    const { iat, exp, ...cleanPayload } = payload as any;
    
    return generateToken(cleanPayload);
  } catch (error) {
    logger.error('JWT refresh failed:', error);
    return null;
  }
}

export function extractToken(authorizationHeader: string | undefined): string | null {
  if (!authorizationHeader || !authorizationHeader.startsWith('Bearer ')) {
    return null;
  }
  
  return authorizationHeader.substring(7); // Remove "Bearer " prefix
}

// Helper for CloudKit integration
export function generateCloudKitCompatibleToken(userId: string): string {
  // When CloudKit is available, this would generate a token that works with Apple's services
  // For now, we'll use our regular JWT but mark it for cloud compatibility
  const payload: JWTPayload = {
    userId,
    email: '', // This would be populated from user data
    // Add CloudKit-specific claims when available
  };
  
  return generateToken(payload);
}

export function isTokenExpiringSoon(token: string, hoursThreshold: number = 24): boolean {
  try {
    const decoded = jwt.decode(token) as any;
    if (!decoded || !decoded.exp) return true;
    
    const expirationTime = decoded.exp * 1000; // Convert to milliseconds
    const thresholdTime = Date.now() + (hoursThreshold * 60 * 60 * 1000);
    
    return expirationTime < thresholdTime;
  } catch (error) {
    return true; // Assume expiring if we can't decode
  }
}
