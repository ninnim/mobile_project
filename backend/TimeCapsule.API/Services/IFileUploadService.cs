namespace TimeCapsule.API.Services;

public interface IFileUploadService
{
    Task<string> SaveFileAsync(IFormFile file);
}
