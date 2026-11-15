FROM node:22-alpine AS build
WORKDIR /app
ARG NEXT_PUBLIC_API_URL=http://localhost:8080
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
COPY packages ./packages
COPY apps/web/package.json apps/web/package-lock.json* ./apps/web/
COPY apps/web/.npmrc ./apps/web/.npmrc
WORKDIR /app/apps/web
RUN npm install --install-links --no-audit --no-fund
COPY apps/web ./
RUN npm run build

FROM nginx:alpine
COPY apps/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/apps/web/out /usr/share/nginx/html
EXPOSE 80
