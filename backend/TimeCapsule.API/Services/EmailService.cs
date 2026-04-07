using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Configuration;
using MimeKit;

namespace TimeCapsule.API.Services;

public class EmailService : IEmailService
{
    private readonly IConfiguration _config;
    private readonly ILogger<EmailService> _logger;

    public EmailService(IConfiguration config, ILogger<EmailService> logger)
    {
        _config = config;
        _logger = logger;
    }

    public async Task SendPasswordResetEmailAsync(string toEmail, string resetUrl)
    {
        var devMode = _config.GetValue<bool>("Email:DevMode");
        if (devMode)
        {
            _logger.LogInformation("DEV MODE — Password Reset URL for {Email}: {Url}", toEmail, resetUrl);
            return;
        }

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(_config["Email:FromName"], _config["Email:FromAddress"]));
        message.To.Add(MailboxAddress.Parse(toEmail));
        message.Subject = "Reset your TimeCapsule password";

        var html = $@"<div style=""background:#0B0D21;color:#fff;padding:32px;font-family:sans-serif"">
            <h2 style=""color:#00E5FF"">TimeCapsule</h2>
            <p>You requested a password reset. Click the link below:</p>
            <a href=""{resetUrl}"" style=""background:#00E5FF;color:#0B0D21;padding:12px 24px;border-radius:24px;text-decoration:none;font-weight:bold"">
                Reset My Password
            </a>
            <p style=""color:#A0A3BD;margin-top:24px"">This link expires in 1 hour. If you didn't request this, ignore this email.</p>
        </div>";

        message.Body = new TextPart("html") { Text = html };

        using var client = new SmtpClient();
        await client.ConnectAsync(_config["Email:SmtpHost"], _config.GetValue<int>("Email:SmtpPort"), SecureSocketOptions.StartTls);
        await client.AuthenticateAsync(_config["Email:SmtpUser"], _config["Email:SmtpPass"]);
        await client.SendAsync(message);
        await client.DisconnectAsync(true);
    }
}
