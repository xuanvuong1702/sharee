using DotNet.Testcontainers.Builders;
using DotNet.Testcontainers.Containers;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Sharee.Api.Services;

namespace Sharee.Tests;

public class ObjectStorageIntegrationTests
{
    [Fact]
    public async Task Saves_and_reads_through_minio_object_storage()
    {
        await using var minio = new ContainerBuilder()
            .WithImage("bitnamilegacy/minio:latest")
            .WithPortBinding(9000, true)
            .WithEnvironment("MINIO_ROOT_USER", "sharee")
            .WithEnvironment("MINIO_ROOT_PASSWORD", "sharee-minio")
            .WithWaitStrategy(Wait.ForUnixContainer().UntilHttpRequestIsSucceeded(r =>
                r.ForPort(9000).ForPath("/minio/health/live")))
            .Build();
        await minio.StartAsync();
        var endpoint = $"http://{minio.Hostname}:{minio.GetMappedPublicPort(9000)}";
        var service = new ObjectStorageService(
            Options.Create(new ObjectStorageOptions
            {
                Enabled = true, Endpoint = endpoint, Bucket = "sharee",
                AccessKey = "sharee", SecretKey = "sharee-minio", UseSsl = false,
                LocalRoot = Path.Combine(Path.GetTempPath(), "sharee-objects-test")
            }), NullLogger<ObjectStorageService>.Instance);

        var bytes = "kyc-document"u8.ToArray();
        await service.SaveAsync("verifications/test/doc.jpg", bytes, "image/jpeg");
        await using var stream = await service.OpenReadAsync("verifications/test/doc.jpg");

        Assert.NotNull(stream);
        using var reader = new StreamReader(stream!);
        Assert.Equal("kyc-document", await reader.ReadToEndAsync());
    }
}
