import { s3, s3Config, isAWSEnabled } from '@/config/aws.config';
import { logger } from '@/utils/logger';
import fs from 'fs';
import path from 'path';
import { promisify } from 'util';

const writeFile = promisify(fs.writeFile);
const readFile = promisify(fs.readFile);
const unlink = promisify(fs.unlink);
const mkdir = promisify(fs.mkdir);

/**
 * AWS S3 Storage Service
 * Handles all file storage operations with S3 or local fallback
 */
export class AWSStorageService {
  private static instance: AWSStorageService;
  private localStoragePath: string = path.join(process.cwd(), 'uploads');

  private constructor() {
    // Ensure local storage directory exists
    this.ensureLocalStorageExists();
  }

  public static getInstance(): AWSStorageService {
    if (!AWSStorageService.instance) {
      AWSStorageService.instance = new AWSStorageService();
    }
    return AWSStorageService.instance;
  }

  private async ensureLocalStorageExists(): Promise<void> {
    try {
      await mkdir(this.localStoragePath, { recursive: true });
    } catch (error) {
      logger.error('Failed to create local storage directory:', error);
    }
  }

  /**
   * Upload a file to S3 or local storage
   */
  async uploadFile(
    file: Buffer | string,
    key: string,
    contentType?: string,
    metadata?: Record<string, string>
  ): Promise<{ url: string; key: string }> {
    try {
      if (isAWSEnabled()) {
        // Upload to S3
        const params = {
          Bucket: s3Config.bucket,
          Key: key,
          Body: file,
          ContentType: contentType || 'application/octet-stream',
          Metadata: metadata || {}
        };

        const result = await s3.upload(params).promise();
        logger.info(`File uploaded to S3: ${result.Location}`);

        return {
          url: result.Location,
          key: result.Key
        };
      } else {
        // Fallback to local storage
        const localPath = path.join(this.localStoragePath, key);
        const localDir = path.dirname(localPath);
        
        await mkdir(localDir, { recursive: true });
        
        if (typeof file === 'string') {
          await writeFile(localPath, file);
        } else {
          await writeFile(localPath, file);
        }

        logger.info(`File saved locally: ${localPath}`);

        return {
          url: `/uploads/${key}`,
          key: key
        };
      }
    } catch (error) {
      logger.error('Failed to upload file:', error);
      throw new Error('File upload failed');
    }
  }

  /**
   * Download a file from S3 or local storage
   */
  async downloadFile(key: string): Promise<Buffer> {
    try {
      if (isAWSEnabled()) {
        // Download from S3
        const params = {
          Bucket: s3Config.bucket,
          Key: key
        };

        const result = await s3.getObject(params).promise();
        logger.info(`File downloaded from S3: ${key}`);

        return result.Body as Buffer;
      } else {
        // Read from local storage
        const localPath = path.join(this.localStoragePath, key);
        const file = await readFile(localPath);
        
        logger.info(`File read from local storage: ${localPath}`);
        return file;
      }
    } catch (error) {
      logger.error('Failed to download file:', error);
      throw new Error('File download failed');
    }
  }

  /**
   * Delete a file from S3 or local storage
   */
  async deleteFile(key: string): Promise<boolean> {
    try {
      if (isAWSEnabled()) {
        // Delete from S3
        const params = {
          Bucket: s3Config.bucket,
          Key: key
        };

        await s3.deleteObject(params).promise();
        logger.info(`File deleted from S3: ${key}`);

        return true;
      } else {
        // Delete from local storage
        const localPath = path.join(this.localStoragePath, key);
        await unlink(localPath);
        
        logger.info(`File deleted from local storage: ${localPath}`);
        return true;
      }
    } catch (error) {
      logger.error('Failed to delete file:', error);
      return false;
    }
  }

  /**
   * Generate a presigned URL for direct upload/download
   */
  async getPresignedUrl(
    key: string,
    operation: 'getObject' | 'putObject' = 'getObject',
    expiresIn: number = 3600
  ): Promise<string> {
    try {
      if (isAWSEnabled()) {
        // Generate S3 presigned URL
        const params = {
          Bucket: s3Config.bucket,
          Key: key,
          Expires: expiresIn
        };

        const url = await s3.getSignedUrlPromise(operation, params);
        logger.info(`Presigned URL generated for ${operation}: ${key}`);

        return url;
      } else {
        // Return local URL
        const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 3000}`;
        return `${baseUrl}/uploads/${key}`;
      }
    } catch (error) {
      logger.error('Failed to generate presigned URL:', error);
      throw new Error('Failed to generate URL');
    }
  }

  /**
   * List files in a directory/prefix
   */
  async listFiles(prefix: string): Promise<Array<{ key: string; size: number; lastModified: Date }>> {
    try {
      if (isAWSEnabled()) {
        // List from S3
        const params = {
          Bucket: s3Config.bucket,
          Prefix: prefix
        };

        const result = await s3.listObjectsV2(params).promise();
        
        return (result.Contents || []).map(item => ({
          key: item.Key || '',
          size: item.Size || 0,
          lastModified: item.LastModified || new Date()
        }));
      } else {
        // List from local storage
        const localPath = path.join(this.localStoragePath, prefix);
        const files: Array<{ key: string; size: number; lastModified: Date }> = [];

        if (fs.existsSync(localPath)) {
          const items = fs.readdirSync(localPath);
          
          for (const item of items) {
            const itemPath = path.join(localPath, item);
            const stats = fs.statSync(itemPath);
            
            if (stats.isFile()) {
              files.push({
                key: path.join(prefix, item),
                size: stats.size,
                lastModified: stats.mtime
              });
            }
          }
        }

        return files;
      }
    } catch (error) {
      logger.error('Failed to list files:', error);
      return [];
    }
  }

  /**
   * Upload user avatar
   */
  async uploadAvatar(userId: string, imageBuffer: Buffer, contentType: string): Promise<string> {
    const key = `avatars/${userId}/${Date.now()}.${contentType.split('/')[1]}`;
    const result = await this.uploadFile(imageBuffer, key, contentType, {
      userId,
      type: 'avatar'
    });
    return result.url;
  }

  /**
   * Upload household image
   */
  async uploadHouseholdImage(householdId: string, imageBuffer: Buffer, contentType: string): Promise<string> {
    const key = `households/${householdId}/${Date.now()}.${contentType.split('/')[1]}`;
    const result = await this.uploadFile(imageBuffer, key, contentType, {
      householdId,
      type: 'household'
    });
    return result.url;
  }

  /**
   * Upload task attachment
   */
  async uploadTaskAttachment(taskId: string, file: Buffer, filename: string, contentType: string): Promise<string> {
    const key = `tasks/${taskId}/${Date.now()}-${filename}`;
    const result = await this.uploadFile(file, key, contentType, {
      taskId,
      type: 'attachment',
      originalName: filename
    });
    return result.url;
  }
}

export default AWSStorageService;
