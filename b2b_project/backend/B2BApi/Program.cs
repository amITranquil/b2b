using Microsoft.EntityFrameworkCore;
using B2BApi.Data;
using B2BApi.Services;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using System.Security.Cryptography.X509Certificates;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// HTTPS sertifika ayarları - environment variable'dan okunur
// Kestrel otomatik olarak --urls parametresindeki https portlarını kullanır
Environment.SetEnvironmentVariable("ASPNETCORE_Kestrel__Certificates__Default__Path",
    Environment.GetEnvironmentVariable("ASPNETCORE_Kestrel__Certificates__Default__Path") ?? "/home/dietpi/b2bapi/certs/letsencrypt.pfx");
Environment.SetEnvironmentVariable("ASPNETCORE_Kestrel__Certificates__Default__Password",
    Environment.GetEnvironmentVariable("ASPNETCORE_Kestrel__Certificates__Default__Password") ?? "B2BApiCert2024");

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add Entity Framework
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlite(builder.Configuration.GetConnectionString("DefaultConnection") ?? 
                     "Data Source=b2b_products.db"));

// Add JWT Service
builder.Services.AddScoped<JwtService>();

// Add JWT Authentication
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"]!))
        };
    });

// Add Database Backup Service
builder.Services.AddHostedService<DatabaseBackupService>();

// Add B2B Scraper Service
builder.Services.AddScoped<B2BScraperService>();

// Add Image Download Service
builder.Services.AddHttpClient<ImageDownloadService>();
builder.Services.AddScoped<ImageDownloadService>();

// Add CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutter", policy =>
    {
        // Development ve Production için tüm origin'lere izin
        // Flutter Web localhost'tan farklı portlardan çalışabilir
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

var app = builder.Build();

// Create database if it doesn't exist
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    context.Database.EnsureCreated();
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// HTTPS redirection sadece mixed mode'da gerekli
// app.UseHttpsRedirection();

// CORS'u static file'lardan önce ekle
app.UseCors("AllowFlutter");

// Static file serving - IMAGES için HER ZAMAN aktif
app.UseStaticFiles(new StaticFileOptions
{
    OnPrepareResponse = ctx =>
    {
        // Static file'lar için CORS header'ları ekle
        ctx.Context.Response.Headers.Append("Access-Control-Allow-Origin", "*");
        ctx.Context.Response.Headers.Append("Access-Control-Allow-Methods", "GET, OPTIONS");
        ctx.Context.Response.Headers.Append("Access-Control-Allow-Headers", "*");
    }
});

// DEVELOPMENT: index.html default file olarak serve et
if (app.Environment.IsDevelopment())
{
    app.UseDefaultFiles(); // index.html'i default file olarak kullan
}

// Authentication & Authorization
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
