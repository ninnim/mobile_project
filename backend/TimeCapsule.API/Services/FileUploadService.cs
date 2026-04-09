namespace TimeCapsule.API.Services;

public class FileUploadService : IFileUploadService
{
    private static readonly HashSet<string> AllowedExtensions = new(StringComparer.OrdinalIgnoreCase)
        { ".jpg", ".jpeg", ".png", ".gif", ".mp4", ".mov", ".m4a", ".aac", ".mp3", ".wav" };
    private static readonly Dictionary<string, string[]> AllowedMimeTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        { ".jpg",  new[] { "image/jpeg" } },
        { ".jpeg", new[] { "image/jpeg" } },
        { ".png",  new[] { "image/png"  } },
        { ".gif",  new[] { "image/gif"  } },
        { ".mp4",  new[] { "video/mp4"  } },
        { ".mov",  new[] { "video/quicktime" } },
        { ".m4a",  new[] { "audio/mp4", "audio/x-m4a", "audio/m4a", "application/octet-stream" } },
        { ".aac",  new[] { "audio/aac", "audio/x-aac", "application/octet-stream" } },
        { ".mp3",  new[] { "audio/mpeg", "audio/mp3" } },
        { ".wav",  new[] { "audio/wav", "audio/x-wav", "audio/wave" } }
    };
    private const long MaxFileSizeBytes = 50 * 1024 * 1024; // 50 MB
    private readonly string _uploadPath;

    public FileUploadService(IWebHostEnvironment env)
    {
        _uploadPath = Path.Combine(env.ContentRootPath, "uploads");
        Directory.CreateDirectory(_uploadPath);
    }

    public async Task<string> SaveFileAsync(IFormFile file)
    {
        if (file.Length > MaxFileSizeBytes)
            throw new InvalidOperationException("File exceeds maximum size of 50MB.");

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedExtensions.Contains(ext))
            throw new InvalidOperationException($"File type '{ext}' is not allowed.");

        if (!AllowedMimeTypes.TryGetValue(ext, out var validMimes) || !validMimes.Contains(file.ContentType.ToLower()))
            throw new InvalidOperationException("File content type does not match extension.");

        // Sanitize filename: strip path traversal chars
        var safeName = Path.GetFileName(file.FileName)
            .Replace("..", "")
            .Replace("/", "")
            .Replace("\\", "")
            .Replace(":", "")
            .Trim();
        if (string.IsNullOrWhiteSpace(safeName)) safeName = "file";

        var fileName = $"{Guid.NewGuid()}_{safeName}";
        var filePath = Path.Combine(_uploadPath, fileName);

        await using var stream = new FileStream(filePath, FileMode.Create);
        await file.CopyToAsync(stream);

        return $"uploads/{fileName}";
    }
}
