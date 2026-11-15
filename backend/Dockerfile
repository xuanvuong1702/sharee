FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY src/Sharee.Api/Sharee.Api.csproj src/Sharee.Api/
RUN dotnet restore src/Sharee.Api/Sharee.Api.csproj
COPY src/Sharee.Api/ src/Sharee.Api/
RUN dotnet publish src/Sharee.Api/Sharee.Api.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build --chown=app:app /app/publish .
RUN mkdir -p /data/verifications && chown -R app:app /data
USER app
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS http://localhost:8080/health/ready || exit 1
ENTRYPOINT ["dotnet", "Sharee.Api.dll"]
