using System.Diagnostics;
using System.Net;
using System.Text;
using System.Threading.RateLimiting;
using Dapper;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using Npgsql;
using Sharee.Api.Contracts;
using Sharee.Api.Endpoints;
using Sharee.Api.Hubs;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;
using Sharee.Api.Workers;

AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);
Dapper.DefaultTypeMap.MatchNamesWithUnderscores = true;

var builder = WebApplication.CreateBuilder(args);
var config = builder.Configuration;
var isProduction = builder.Environment.IsProduction();
SensitiveDataProtector.EnsureConfigured(isProduction);
var demoMode = config.GetValue("Demo:Mode", false);

if (config.GetValue("Logging:Json", false))
{
    builder.Logging.ClearProviders();
    builder.Logging.AddJsonConsole(o =>
    {
        o.IncludeScopes = true;
        o.UseUtcTimestamp = true;
    });
}

var connectionString = config.GetConnectionString("Db");
if (string.IsNullOrWhiteSpace(connectionString))
{
    if (isProduction) throw new InvalidOperationException("ConnectionStrings:Db is required");
    connectionString = "Host=localhost;Port=5432;Database=sharee;Username=sharee;Password=sharee";
}

builder.WebHost.ConfigureKestrel(o => o.Limits.MaxRequestBodySize = 12 * 1024 * 1024);
builder.Services.AddSingleton(NpgsqlDataSource.Create(connectionString));
builder.Services.AddSingleton<Db>();
builder.Services.AddSingleton<Migrator>();
builder.Services.AddSingleton(Microsoft.Extensions.Options.Options.Create(new VerificationStorageOptions
{
    RootPath = config["Storage:VerificationRoot"] ?? "./data/verifications"
}));
builder.Services.AddSingleton<VerificationStorage>();
builder.Services.AddSingleton(Microsoft.Extensions.Options.Options.Create(new AppealStorageOptions
{
    RootPath = config["Storage:AppealRoot"] ?? "./data/appeals"
}));
builder.Services.AddSingleton<AppealStorage>();
builder.Services.Configure<ObjectStorageOptions>(config.GetSection("ObjectStorage"));
builder.Services.AddSingleton<ObjectStorageService>();
builder.Services.AddSingleton<SensitiveDataBackfill>();
builder.Services.AddScoped<OtpService>();
builder.Services.AddSingleton<TokenService>();
builder.Services.AddSingleton<RefreshTokenService>();
builder.Services.AddSingleton<JwtOptions>();
builder.Services.AddScoped<LedgerService>();
builder.Services.AddScoped<BookingSettlementService>();
builder.Services.AddScoped<ReadService>();
builder.Services.AddScoped<ChatService>();
builder.Services.AddScoped<RecurringTripService>();
builder.Services.AddScoped<TrackingService>();
builder.Services.AddHostedService<RecurringWorker>();
builder.Services.AddHostedService<OutboxWorker>();
builder.Services.AddHostedService<BookingExpiryWorker>();
builder.Services.AddHostedService<RideExpiryWorker>();
builder.Services.AddHostedService<BookingReleaseWorker>();
builder.Services.AddHostedService<MaintenanceWorker>();
builder.Services.AddMemoryCache(o => o.SizeLimit = 10_000);
var signalR = builder.Services.AddSignalR();
var redisConnection = config.GetConnectionString("Redis");
if (!string.IsNullOrWhiteSpace(redisConnection))
{
    signalR.AddStackExchangeRedis(redisConnection, o =>
        o.Configuration.ChannelPrefix = StackExchange.Redis.RedisChannel.Literal("sharee"));
    try
    {
        var multiplexer = StackExchange.Redis.ConnectionMultiplexer.Connect(redisConnection);
        builder.Services.AddSingleton<StackExchange.Redis.IConnectionMultiplexer>(multiplexer);
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"Redis unavailable for OTP guard: {ex.Message}");
    }
}
builder.Services.AddSingleton(sp =>
    new OtpRateGuard(config, sp.GetService<StackExchange.Redis.IConnectionMultiplexer>()));
builder.Services.AddHttpContextAccessor();
builder.Services.AddProblemDetails();
builder.Services.AddResponseCompression(o => o.EnableForHttps = true);
builder.Services.AddHttpClient("twilio", c => c.Timeout = TimeSpan.FromSeconds(10));
builder.Services.AddHttpClient("payos", c => c.Timeout = TimeSpan.FromSeconds(15));
builder.Services.AddHttpClient("geo", c => c.Timeout = TimeSpan.FromSeconds(8));
builder.Services.AddScoped<GeoService>();

var paymentProvider = config["Payments:Provider"] ?? "mock";
var payos = config.GetSection("PayOS").Get<PayOsOptions>() ?? new PayOsOptions();
builder.Services.AddSingleton(payos);
builder.Services.AddScoped<PayOsService>();
var bankPayout = config.GetSection("BankPayout").Get<BankPayoutOptions>() ?? new BankPayoutOptions();
builder.Services.AddSingleton(bankPayout);
builder.Services.AddHttpClient("bankpayout", c => c.Timeout = TimeSpan.FromSeconds(20));
builder.Services.AddScoped<BankPayoutService>();
builder.Services.AddScoped<PaymentSettlementService>();
if (isProduction && paymentProvider.Equals("payos", StringComparison.OrdinalIgnoreCase))
{
    if (!payos.Enabled || string.IsNullOrWhiteSpace(payos.ClientId)
        || string.IsNullOrWhiteSpace(payos.ApiKey) || string.IsNullOrWhiteSpace(payos.ChecksumKey))
        throw new InvalidOperationException("PayOS is enabled but credentials are incomplete");
}

var push = config.GetSection("Push").Get<PushOptions>() ?? new PushOptions();
builder.Services.AddSingleton(push);
builder.Services.AddHttpClient("push", c => c.Timeout = TimeSpan.FromSeconds(10));
builder.Services.AddSingleton<PushService>();
if (isProduction && push.Enabled && !push.Fcm.Enabled && !push.Apns.Enabled)
    throw new InvalidOperationException("Push is enabled but no FCM/APNs credentials are configured");

var smsProvider = config["Sms:Provider"] ?? "dev";
if (isProduction && smsProvider.Equals("dev", StringComparison.OrdinalIgnoreCase) && !demoMode)
    throw new InvalidOperationException("Sms:Provider=dev is not allowed in production");
if (isProduction && smsProvider.Equals("twilio", StringComparison.OrdinalIgnoreCase)
    && (string.IsNullOrWhiteSpace(config["Twilio:AccountSid"])
        || string.IsNullOrWhiteSpace(config["Twilio:AuthToken"])
        || string.IsNullOrWhiteSpace(config["Twilio:From"])))
    throw new InvalidOperationException("Twilio SMS credentials are incomplete");
builder.Services.AddSingleton<ISmsSender>(sp =>
    smsProvider.Equals("twilio", StringComparison.OrdinalIgnoreCase)
        ? ActivatorUtilities.CreateInstance<TwilioSmsSender>(sp)
        : ActivatorUtilities.CreateInstance<DevSmsSender>(sp));

var origins = config.GetSection("Cors:AllowedOrigins").Get<string[]>()
    ?? new[] { "http://localhost:3000", "http://localhost:8081" };
if (isProduction && origins.Length == 0)
    throw new InvalidOperationException("Cors:AllowedOrigins is required in production");
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod()));

var jwt = config.GetSection("Jwt").Get<JwtOptions>() ?? new JwtOptions();
if (string.IsNullOrWhiteSpace(jwt.Key) || jwt.Key.Length < 32)
{
    if (isProduction) throw new InvalidOperationException("Jwt:Key must be set to at least 32 characters");
    jwt.Key = "sharee-dev-key-change-me-0123456789abcdef";
}
if (isProduction && config.GetValue("Auth:ExposeOtp", false) && !demoMode)
    throw new InvalidOperationException("Auth:ExposeOtp is not allowed in production");
if (isProduction && (config["Auth:OtpPepper"]?.Length ?? 0) < 16 && !demoMode)
    throw new InvalidOperationException("Auth:OtpPepper must be configured in production");
if (isProduction)
{
    RequireSecret(jwt.Key, "Jwt:Key", 32);
    RequireSecret(config["Auth:OtpPepper"], "Auth:OtpPepper", 16);
    if (connectionString.Contains("replace-with", StringComparison.OrdinalIgnoreCase)
        || connectionString.Contains("change-me", StringComparison.OrdinalIgnoreCase))
        throw new InvalidOperationException("Production database credentials still contain placeholders");
}
builder.Services.AddSingleton(jwt);

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx =>
    {
        var key = ctx.User.Identity?.IsAuthenticated == true
            ? $"user:{ctx.User.FindFirst("sub")?.Value}"
            : $"ip:{ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown"}";
        return RateLimitPartition.GetFixedWindowLimiter(key, _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 300,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0
        });
    });
    options.AddFixedWindowLimiter("auth", o =>
    {
        o.PermitLimit = 20;
        o.Window = TimeSpan.FromMinutes(1);
        o.QueueLimit = 0;
    });
});

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
            ClockSkew = TimeSpan.FromSeconds(30),
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

if (config.GetValue("ReverseProxy:TrustForwarded", false))
{
    var trustedProxies = config.GetSection("ReverseProxy:KnownProxies").Get<string[]>() ?? [];
    var trustedNetworks = config.GetSection("ReverseProxy:KnownNetworks").Get<string[]>() ?? [];
    builder.Services.Configure<ForwardedHeadersOptions>(o =>
    {
        o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
        // Never clear the trust list blindly: that lets any client spoof
        // X-Forwarded-For and defeat IP rate limits / OTP audit trails.
        if (trustedProxies.Length == 0 && trustedNetworks.Length == 0)
        {
            Console.Error.WriteLine(
                "ReverseProxy:TrustForwarded is enabled without KnownProxies/KnownNetworks; " +
                "only loopback proxies are trusted.");
            return;
        }
        o.KnownProxies.Clear();
        o.KnownIPNetworks.Clear();
        foreach (var value in trustedProxies)
            if (IPAddress.TryParse(value, out var ip)) o.KnownProxies.Add(ip);
        foreach (var value in trustedNetworks)
            if (System.Net.IPNetwork.TryParse(value, out var network)) o.KnownIPNetworks.Add(network);
    });
}

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

if (config.GetValue("ReverseProxy:TrustForwarded", false))
    app.UseForwardedHeaders();

app.UseExceptionHandler();
app.Use(async (context, next) =>
{
    var requestId = context.Request.Headers["X-Request-Id"].FirstOrDefault();
    if (string.IsNullOrWhiteSpace(requestId)) requestId = context.TraceIdentifier;
    context.Response.Headers["X-Request-Id"] = requestId;

    var headers = context.Response.Headers;
    headers["X-Content-Type-Options"] = "nosniff";
    headers["X-Frame-Options"] = "DENY";
    headers["Referrer-Policy"] = "no-referrer";
    headers["Permissions-Policy"] = "geolocation=(self), camera=(), microphone=()";
    headers["Cross-Origin-Opener-Policy"] = "same-origin";

    var started = Stopwatch.GetTimestamp();
    try
    {
        await next();
    }
    finally
    {
        var elapsed = Stopwatch.GetElapsedTime(started).TotalMilliseconds;
        app.Logger.LogInformation("{Method} {Path} -> {Status} in {Elapsed:0.0}ms [{RequestId}]",
            context.Request.Method, context.Request.Path, context.Response.StatusCode, elapsed, requestId);
    }
});
if (isProduction) app.UseHsts();
app.UseResponseCompression();
app.UseCors();

var swaggerEnabled = !isProduction || config.GetValue("Swagger:Enabled", false);
if (swaggerEnabled)
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "Sharee API v1");
        c.RoutePrefix = "swagger";
    });
}

app.UseAuthentication();
// Authentication must run before the limiter so user-partitioned policies can
// see ctx.User; IP remains the fallback for anonymous requests.
app.UseRateLimiter();
app.UseAuthorization();
app.Use(async (context, next) =>
{
    if (context.Request.Path.StartsWithSegments("/api/admin"))
    {
        var allowedIps = config.GetSection("Admin:AllowedIps").Get<string[]>();
        if (!AdminSecurity.IsIpAllowed(context.Connection.RemoteIpAddress, allowedIps))
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            await context.Response.WriteAsJsonAsync(new { error = "Admin IP không được phép." });
            return;
        }
        var mfaSecret = config["Admin:MfaSecret"];
        if (!AdminSecurity.ValidateTotp(mfaSecret, context.Request.Headers["X-Admin-Mfa"].FirstOrDefault()))
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            await context.Response.WriteAsJsonAsync(new { error = "Thiếu hoặc sai mã MFA admin." });
            return;
        }
    }
    await next();
});

app.MapGet("/", () => Results.Ok(new
{
    name = "Sharee API",
    version = "1.0.0",
    docs = swaggerEnabled ? "/swagger" : null,
    health = "/health/ready"
}));
app.MapGet("/health/live", () => Results.Ok(new { status = "live" }));
app.MapGet("/health/ready", async (Db db, IServiceProvider services, CancellationToken ct) =>
{
    try
    {
        await using var conn = await db.OpenAsync(ct);
        var ok = await conn.ExecuteScalarAsync<int>("select 1");
        var redis = services.GetService<StackExchange.Redis.IConnectionMultiplexer>();
        var redisOk = redis is null || redis.IsConnected;
        return ok == 1 && redisOk
            ? Results.Ok(new { status = "ready", db = true, redis = redisOk })
            : Results.Json(new { status = "degraded", db = ok == 1, redis = redisOk },
                statusCode: 503);
    }
    catch (Exception ex)
    {
        app.Logger.LogError(ex, "Readiness check failed");
        return Results.Json(new { status = "unhealthy" }, statusCode: 503);
    }
});
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
app.MapVerificationEndpoints();
app.MapEscrowAppealEndpoints();
app.MapPaymentEndpoints();
app.MapPayOsEndpoints();
app.MapTipEndpoints();
app.MapReviewEndpoints();
app.MapReportEndpoints();
app.MapChatEndpoints();
app.MapAdminEndpoints();
app.MapDailyEndpoints();
app.MapNotificationEndpoints();
app.MapRideEndpoints();
app.MapDriverFinanceEndpoints();
app.MapHub<ChatHub>("/hubs/chat");
app.MapHub<NotificationHub>("/hubs/notifications");

await using (var scope = app.Services.CreateAsyncScope())
{
    var migrator = scope.ServiceProvider.GetRequiredService<Migrator>();
    await migrator.RunAsync();
    await scope.ServiceProvider.GetRequiredService<SensitiveDataBackfill>().RunAsync();
}

app.Run();

static void RequireSecret(string? value, string name, int minLength)
{
    if (string.IsNullOrWhiteSpace(value) || value.Length < minLength)
        throw new InvalidOperationException($"{name} must be at least {minLength} characters in production");
    var lower = value.ToLowerInvariant();
    if (lower.Contains("replace-with") || lower.Contains("change-me")
        || lower.Contains("change-in-production") || lower.Contains("example"))
        throw new InvalidOperationException($"{name} still contains a placeholder value");
}

public partial class Program;
