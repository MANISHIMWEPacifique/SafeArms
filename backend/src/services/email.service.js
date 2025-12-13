const nodemailer = require('nodemailer');
require('dotenv').config();
const logger = require('../utils/logger');

// Create reusable transporter
const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT) || 587,
    secure: process.env.SMTP_SECURE === 'true', // true for 465, false for other ports
    auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASSWORD
    }
});

// Verify transporter configuration
transporter.verify((error, success) => {
    if (error) {
        logger.error('Email transporter error:', error);
    } else {
        logger.info('✅ Email service ready');
    }
});

/**
 * Send OTP code via email
 * @param {string} email - Recipient email
 * @param {string} fullName - Recipient name
 * @param {string} otp - 6-digit OTP code
 * @returns {Promise<Object>}
 */
const sendOTPEmail = async (email, fullName, otp) => {
    try {
        const mailOptions = {
            from: `${process.env.SMTP_FROM_NAME || 'SafeArms System'} <${process.env.SMTP_FROM_EMAIL || process.env.SMTP_USER}>`,
            to: email,
            subject: 'SafeArms Login Verification Code',
            html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #1a56db; color: white; padding: 20px; text-align: center; }
            .content { background: #f9fafb; padding: 30px; margin: 20px 0; border-radius: 8px; }
            .otp-code { font-size: 32px; font-weight: bold; color: #1a56db; text-align: center; letter-spacing: 5px; padding: 20px; background: white; border-radius: 8px; margin: 20px 0; }
            .footer { text-align: center; color: #6b7280; font-size: 12px; margin-top: 20px; }
            .warning { background: #fef3c7; border-left: 4px solid #f59e0b; padding: 15px; margin: 20px 0; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🔒 SafeArms</h1>
              <p>Rwanda National Police - Firearm Control System</p>
            </div>
            <div class="content">
              <h2>Hello ${fullName},</h2>
              <p>You have requested to login to SafeArms. Your verification code is:</p>
              
              <div class="otp-code">${otp}</div>
              
              <p><strong>This code will expire in 5 minutes.</strong></p>
              
              <div class="warning">
                <strong>⚠️ Security Notice:</strong><br>
                If you did not request this code, please contact your system administrator immediately.
                Do not share this code with anyone.
              </div>
              
              <p>For security reasons:</p>
              <ul>
                <li>This code can only be used once</li>
                <li>Enter the code exactly as shown</li>
                <li>Do not forward this email</li>
              </ul>
            </div>
            <div class="footer">
              <p>Rwanda National Police - SafeArms System</p>
              <p>This is an automated message, please do not reply to this email.</p>
            </div>
          </div>
        </body>
        </html>
      `
        };

        const info = await transporter.sendMail(mailOptions);

        logger.info(`OTP email sent to ${email}`);

        return {
            success: true,
            messageId: info.messageId
        };
    } catch (error) {
        logger.error('Send OTP email error:', error);
        throw new Error('Failed to send OTP email');
    }
};

/**
 * Send anomaly alert email
 * @param {string} email - Recipient email
 * @param {string} fullName - Recipient name
 * @param {Object} anomalyData - Anomaly details
 * @returns {Promise<Object>}
 */
const sendAnomalyAlert = async (email, fullName, anomalyData) => {
    try {
        const { anomaly_id, severity, anomaly_score, firearm, officer, unit } = anomalyData;

        const severityColor = {
            critical: '#dc2626',
            high: '#ea580c',
            medium: '#ca8a04',
            low: '#2563eb'
        }[severity] || '#6b7280';

        const mailOptions = {
            from: `${process.env.SMTP_FROM_NAME || 'SafeArms System'} <${process.env.SMTP_FROM_EMAIL || process.env.SMTP_USER}>`,
            to: email,
            subject: `🚨 SafeArms: ${severity.toUpperCase()} Anomaly Detected - ${anomaly_id}`,
            html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: ${severityColor}; color: white; padding: 20px; text-align: center; }
            .content { background: #f9fafb; padding: 30px; margin: 20px 0; border-radius: 8px; }
            .alert-box { background: white; border-left: 4px solid ${severityColor}; padding: 15px; margin: 15px 0; }
            .details { background: white; padding: 15px; border-radius: 8px; margin: 15px 0; }
            .details table { width: 100%; }
            .details td { padding: 8px; border-bottom: 1px solid #e5e7eb; }
            .details td:first-child { font-weight: bold; width: 40%; }
            .button { display: inline-block; background: #1a56db; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 15px 0; }
            .footer { text-align: center; color: #6b7280; font-size: 12px; margin-top: 20px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🚨 Anomaly Alert</h1>
              <h2>${severity.toUpperCase()} Severity</h2>
            </div>
            <div class="content">
              <h3>Hello ${fullName},</h3>
              <p>An anomaly has been detected in the firearm custody system:</p>
              
              <div class="alert-box">
                <strong>Anomaly ID:</strong> ${anomaly_id}<br>
                <strong>Severity:</strong> <span style="color: ${severityColor}">${severity.toUpperCase()}</span><br>
                <strong>Anomaly Score:</strong> ${(anomaly_score * 100).toFixed(1)}%
              </div>
              
              <div class="details">
                <h4>Details:</h4>
                <table>
                  <tr>
                    <td>Firearm:</td>
                    <td>${firearm}</td>
                  </tr>
                  <tr>
                    <td>Officer:</td>
                    <td>${officer}</td>
                  </tr>
                  <tr>
                    <td>Unit:</td>
                    <td>${unit}</td>
                  </tr>
                  <tr>
                    <td>Detected:</td>
                    <td>${new Date().toLocaleString()}</td>
                  </tr>
                </table>
              </div>
              
              <p><strong>Action Required:</strong> Please review this anomaly and investigate as necessary.</p>
              
              <a href="${process.env.API_BASE_URL}/anomalies/${anomaly_id}" class="button">View Anomaly Details</a>
            </div>
            <div class="footer">
              <p>Rwanda National Police - SafeArms System</p>
              <p>This is an automated alert. For assistance, contact your system administrator.</p>
            </div>
          </div>
        </body>
        </html>
      `
        };

        const info = await transporter.sendMail(mailOptions);

        logger.info(`Anomaly alert sent to ${email} for anomaly ${anomaly_id}`);

        return {
            success: true,
            messageId: info.messageId
        };
    } catch (error) {
        logger.error('Send anomaly alert error:', error);
        throw new Error('Failed to send anomaly alert');
    }
};

/**
 * Send workflow approval notification
 * @param {string} email
 * @param {string} fullName
 * @param {Object} workflowData
 * @returns {Promise<Object>}
 */
const sendApprovalNotification = async (email, fullName, workflowData) => {
    try {
        const { type, status, details } = workflowData;

        const mailOptions = {
            from: `${process.env.SMTP_FROM_NAME || 'SafeArms System'} <${process.env.SMTP_FROM_EMAIL || process.env.SMTP_USER}>`,
            to: email,
            subject: `SafeArms: ${type} ${status}`,
            html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #1a56db; color: white; padding: 20px; text-align: center; }
            .content { background: #f9fafb; padding: 30px; margin: 20px 0; border-radius: 8px; }
            .status { font-size: 20px; font-weight: bold; color: #059669; padding: 15px; background: #d1fae5; border-radius: 8px; text-align: center; margin: 15px 0; }
            .footer { text-align: center; color: #6b7280; font-size: 12px; margin-top: 20px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>SafeArms Notification</h1>
            </div>
            <div class="content">
              <h3>Hello ${fullName},</h3>
              <p>Your ${type} has been processed:</p>
              
              <div class="status">${status}</div>
              
              <p>${details}</p>
            </div>
            <div class="footer">
              <p>Rwanda National Police - SafeArms System</p>
            </div>
          </div>
        </body>
        </html>
      `
        };

        const info = await transporter.sendMail(mailOptions);

        logger.info(`Approval notification sent to ${email}`);

        return {
            success: true,
            messageId: info.messageId
        };
    } catch (error) {
        logger.error('Send approval notification error:', error);
        throw new Error('Failed to send approval notification');
    }
};

module.exports = {
    sendOTPEmail,
    sendAnomalyAlert,
    sendApprovalNotification
};
