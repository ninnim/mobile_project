namespace TimeCapsule.API.Services;
public interface IEmailService
{
    Task SendPasswordResetEmailAsync(string toEmail, string resetUrl);
}
