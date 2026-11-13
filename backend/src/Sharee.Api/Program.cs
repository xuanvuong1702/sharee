using System.Text;
using Dapper;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using Npgsql;
using Sharee.Api.Contracts;
using Sharee.Api.Endpoints;
using Sharee.Api.Hubs;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;
using Sharee.Api.Workers;

// Npgsql legacy timestamp behaviour: timestamptz <-> DateTimeOffset.
// Keeps DTO records with DateTimeOffset working with Dapper.
AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);

Dapper.DefaultTypeMap.MatchNamesWithUnderscores = true;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("Db")
    ?? "Host=localhost;Port=5432;Database=sharee;Username=sharee;Password=sharee";

builder.Services.AddSingleton(NpgsqlDataSource.Create(connectionString));
builder.Services.AddSingleton<Db>();
builder.Services.AddSingleton<Migrator>();
builder.Services.AddSingleton<OtpService>();
builder.Services.AddSingleton<TokenService>();
builder.Services.AddSingleton<RefreshTokenService>();
builder.Services.AddSingleton<JwtOptions>();
builder.Services.AddScoped<LedgerService>();
builder.Services.AddScoped<ReadService>();
builder.Services.AddScoped<ChatService>();
builder.Services.AddScoped<RecurringTripService>();
builder.Services.AddScoped<TrackingService>();
builder.Services.AddHostedService<RecurringWorker>();
builder.Services.AddMemoryCache();
builder.Services.AddSignalR();
builder.Services.AddHostedService<OutboxWorker>();
builder.Services.AddHttpContextAccessor();

builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

var jwt = builder.Configuration.GetSection("Jwt").Get<JwtOptions>() ?? new JwtOptions();
if (string.IsNullOrWhiteSpace(jwt.Key) || jwt.Key.Length < 32)
{
    jwt.Key = "sharee-dev-key-change-me-0123456789abcdef";
}
builder.Services.AddSingleton(jwt);

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false;
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,
            ValidateAudience = true,
            ValidAudience = jwt.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(2),
            NameClaimType = "name",
            RoleClaimType = "role"
        };
        o.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                var token = ctx.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(token) &&
                    ctx.HttpContext.Request.Path.StartsWithSegments("/hubs"))
                {
                    ctx.Token = token;
                }
                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddAuthorization(o =>
    o.AddPolicy("admin", p => p.RequireRole("admin")));

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Sharee API",
        Version = "v1",
        Description = "Carpooling marketplace + Daily line mode"
    });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Name = "Authorization"
    });
});

builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
});

var app = builder.Build();

app.UseCors();
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "Sharee API v1");
    c.RoutePrefix = "swagger";
});

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => Results.Ok(new
{
    name = "Sharee API",
    version = "1.0.0",
    docs = "/swagger",
    health = "/health"
}));
app.MapGet("/health", async (Db db, CancellationToken ct) =>
{
    await using var conn = await db.OpenAsync(ct);
    var ok = await conn.ExecuteScalarAsync<int>("select 1");
    return Results.Ok(new { status = "ok", db = ok == 1 });
});

app.MapAuthEndpoints();
app.MapUserEndpoints();
app.MapTripEndpoints();
app.MapRecurringEndpoints();
app.MapTrackingEndpoints();
app.MapBookingEndpoints();
app.MapPaymentEndpoints();
app.MapReviewEndpoints();
app.MapReportEndpoints();
app.MapChatEndpoints();
app.MapAdminEndpoints();
app.MapDailyEndpoints();
app.MapNotificationEndpoints();
app.MapHub<ChatHub>("/hubs/chat");
app.MapHub<NotificationHub>("/hubs/notifications");

// Migrate + seed with retry so docker-compose can start api and db together.
await using (var scope = app.Services.CreateAsyncScope())
{
    var migrator = scope.ServiceProvider.GetRequiredService<Migrator>();
    await migrator.RunAsync();
}

app.Run();

public partial class Program;
