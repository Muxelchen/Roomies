import nodemailer, { Transporter } from 'nodemailer';

type MailerConfig = {
  host?: string;
  port?: number;
  secure?: boolean;
  user?: string;
  pass?: string;
  service?: string;
  fromAddress: string;
};

export class MailService {
  private static instance: MailService | null = null;
  private transporter: Transporter | null = null;
  private readonly fromAddress: string;

  private constructor(config: MailerConfig) {
    this.fromAddress = config.fromAddress;

    // Prefer explicit SMTP credentials if provided
    if (config.host && config.port && config.user && config.pass) {
      this.transporter = nodemailer.createTransport({
        host: config.host,
        port: config.port,
        secure: Boolean(config.secure),
        auth: {
          user: config.user,
          pass: config.pass,
        },
      });
      return;
    }

    // Fallback to well-known service (e.g., Gmail) if specified
    if (config.service && config.user && config.pass) {
      this.transporter = nodemailer.createTransport({
        service: config.service,
        auth: {
          user: config.user,
          pass: config.pass,
        },
      });
    }
  }

  static getInstance(): MailService {
    if (!MailService.instance) {
      const fromAddress = process.env.EMAIL_FROM || 'roomiesappteam@gmail.com';
      const config: MailerConfig = {
        fromAddress,
        host: process.env.SMTP_HOST,
        port: process.env.SMTP_PORT ? Number(process.env.SMTP_PORT) : undefined,
        secure: process.env.SMTP_SECURE ? process.env.SMTP_SECURE === 'true' : undefined,
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
        service: process.env.SMTP_SERVICE, // e.g. 'gmail'
      };
      MailService.instance = new MailService(config);
    }
    return MailService.instance;
  }

  async sendMail(params: {
    to: string;
    subject: string;
    text?: string;
    html?: string;
    from?: string;
  }): Promise<void> {
    // If mail transport is not configured, no-op gracefully for now
    if (!this.transporter) {
      return;
    }

    await this.transporter.sendMail({
      from: params.from || this.fromAddress,
      to: params.to,
      subject: params.subject,
      text: params.text,
      html: params.html,
    });
  }
}

export default MailService;


