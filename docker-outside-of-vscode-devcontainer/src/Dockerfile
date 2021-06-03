FROM mcr.microsoft.com/dotnet/sdk:5.0 AS builder
WORKDIR /src
COPY . .
RUN dotnet publish -o publish

FROM mcr.microsoft.com/dotnet/aspnet:5.0 AS runtime
WORKDIR /app
COPY --from=builder /src/publish/ /app
EXPOSE 80
ENTRYPOINT ["dotnet", "src.dll"]