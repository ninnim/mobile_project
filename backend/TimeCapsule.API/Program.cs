using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using TimeCapsule.API.Data;
using TimeCapsule.API.Hubs;
using TimeCapsule.API.Middleware;
using TimeCapsule.API.Services;

var builder = WebApplication.CreateBuilder(args);
builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: true);

// Railway provides PORT env var — use it if present
var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";
builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

// Services
builder.Services.AddControllers();
builder.Services.AddSignalR();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "TimeCapsule API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme.",
        Name = "Authorization", In = ParameterLocation.Header, Type = SecuritySchemeType.ApiKey, Scheme = "Bearer"
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        { new OpenApiSecurityScheme { Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" } }, Array.Empty<string>() }
    });
});

// Database
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// JWT Auth
var jwtSecret = builder.Configuration["JwtSettings:Secret"]!;
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
            ValidateIssuer = true, ValidIssuer = builder.Configuration["JwtSettings:Issuer"],
            ValidateAudience = true, ValidAudience = builder.Configuration["JwtSettings:Audience"],
            ValidateLifetime = true,
            NameClaimType = System.Security.Claims.ClaimTypes.NameIdentifier
        };
        // Allow SignalR to read JWT from query string
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                var path = context.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/chathub"))
                {
                    context.Token = accessToken;
                }
                return Task.CompletedTask;
            }
        };
    });

// CORS — AllowCredentials required for SignalR WebSocket
builder.Services.AddCors(options =>
    options.AddDefaultPolicy(p => p
        .SetIsOriginAllowed(_ => true)
        .AllowAnyHeader()
        .AllowAnyMethod()
        .AllowCredentials()));

// HttpClient (needed for social auth token verification)
builder.Services.AddHttpClient();

// DI
builder.Services.AddSingleton<IEmailService, EmailService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ICapsuleService, CapsuleService>();
builder.Services.AddScoped<IChatService, ChatService>();
builder.Services.AddScoped<IPostService, PostService>();
builder.Services.AddScoped<IGameRoomService, GameRoomService>();
builder.Services.AddScoped<ITripAnalyzerService, TripAnalyzerService>();
builder.Services.AddScoped<IFriendshipService, FriendshipService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddSingleton<IFileUploadService, FileUploadService>();
builder.Services.AddSingleton<IFcmNotificationService, FcmNotificationService>();

var app = builder.Build();

// Create uploads directory
var uploadsPath = Path.Combine(app.Environment.ContentRootPath, "uploads");
Directory.CreateDirectory(uploadsPath);

// Middleware pipeline (order matters per CLAUDE.md)
app.UseMiddleware<GlobalExceptionHandler>();
app.UseCors();
app.UseSwagger();
app.UseSwaggerUI();
app.UseAuthentication();
app.UseAuthorization();
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(uploadsPath),
    RequestPath = "/uploads"
});
app.MapControllers();
app.MapHub<ChatHub>("/chathub");
app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));

app.Run();
