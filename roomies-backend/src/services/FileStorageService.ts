import fs from 'fs';
import path from 'path';
import { promisify } from 'util';

import { logger } from '@/utils/logger';

const writeFile = promisify(fs.writeFile);
const readFile = promisify(fs.readFile);
const unlink = promisify(fs.unlink);
const mkdir = promisify(fs.mkdir);

/**
 * File Storage Service (local-only) and CloudKit-ready scaffold
 * Handles file storage operations locally. Presigned URLs map to local URLs.
 */
export class FileStorageService {
  private static instance: FileStorageService;
  private localStoragePath: string = path.join(process.cwd(), 'uploads');

  private constructor() {
    // Ensure local storage directory exists
    this.ensureLocalStorageExists();
  }

  public static getInstance(): FileStorageService {
    if (!FileStorageService.instance) {
      FileStorageService.instance = new FileStorageService();
    }
    return FileStorageService.instance;
  }

  private async ensureLocalStorageExists(): Promise<void> {
    try {
      await mkdir(this.localStoragePath, { recursive: true });
    } catch (error) {
      logger.error('Failed to create local storage directory:', error);
    }
  }

  /**
   * Upload a file to local storage
   */
  async uploadFile(
    file: Buffer | string,
    key: string,
    contentType?: string,
    metadata?: Record<string, string>
  ): Promise<{ url: string; key: string }> {
    try {
      {
        // Local storage
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
   * Download a file from local storage
   */
  async downloadFile(key: string): Promise<Buffer> {
    try {
      {
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
   * Delete a file from local storage
   */
  async deleteFile(key: string): Promise<boolean> {
    try {
      {
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
   * Generate a URL for direct download (local)
   */
  async getPresignedUrl(
    key: string,
    operation: 'getObject' | 'putObject' = 'getObject',
    expiresIn: number = 3600
  ): Promise<string> {
    try {
      {
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
   * List files in a local directory/prefix
   */
  async listFiles(prefix: string): Promise<Array<{ key: string; size: number; lastModified: Date }>> {
    try {
      {
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

export default FileStorageService;


