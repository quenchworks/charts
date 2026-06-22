# Charts de QuenchWorks

[English](README.md) · [العربية](README.ar.md) · **Español**

Charts de Helm clean-room para el catalogo de [QuenchWorks](https://github.com/quenchworks). Cada chart despliega una imagen endurecida 0-CVE de la fabrica de [images](https://quench-works.com/images), la fija estrictamente por digest `sha256`, se publica como un artefacto OCI firmado con cosign en GHCR y aparece en ArtifactHub como **verified publisher** con un esquema de Values.

<p align="center">
  <a href="https://quench-works.com"><img src="https://raw.githubusercontent.com/quenchworks/.github/main/profile/assets/demo.gif" alt="QuenchWorks en una terminal: ejecuta una imagen 0-CVE, verificala con cosign, despliega el chart de Helm y observa como el pod alcanza el estado Running." width="760"></a>
</p>

**50+ charts.** Sin muro de pago, sin cuenta, sin lock-in de proveedor. Exploralos todos en [quench-works.com/charts](https://quench-works.com/charts).

```bash
helm install cache oci://ghcr.io/quenchworks/charts/redis
```

Esa es toda la instalacion. La imagen que despliega ya esta firmada y fijada a un digest, asi que no tienes que rastrear la seguridad de la imagen tu mismo.

## El modelo de seguridad

Tres garantias, integradas en cada chart:

- **Fijado por digest, siempre.** Los charts resuelven las imagenes por `repository@sha256:...`, nunca por tag. Una referencia solo por tag se rechaza a proposito, de modo que un chart fisicamente no puede publicar una imagen no fijada.
- **Una sola linea base endurecida.** Cada chart hereda el mismo contexto de seguridad de pod y contenedor del library chart [`quench-common`](https://github.com/quenchworks/common): nonroot, sistema de archivos raiz de solo lectura, sin escalada de privilegios, todas las capacidades eliminadas, seccomp `RuntimeDefault`. Arreglalo una vez, arreglalo en todas partes.
- **Procedencia verificable.** Los charts estan firmados con cosign keyless, y las imagenes a las que apuntan estan firmadas y llevan SBOM. Puedes comprobarlo todo tu mismo.

## El catalogo

| Categoria | Charts |
|----------|--------|
| Relacional | `postgresql` · `mariadb` · `mysql` · `cockroachdb` ⚠️ |
| Documental | `couchdb` · `ferretdb` · `documentdb` · `postgres-documentdb` · `mongodb` ⚠️ |
| Columna ancha | `cassandra` · `scylladb` |
| Clave-valor / cache | `valkey` · `redis` · `memcached` · `dragonfly` ⚠️ |
| Busqueda / vectores | `opensearch` · `solr` · `meilisearch` · `qdrant` · `elasticsearch` ⚠️ |
| Series temporales | `influxdb` · `victoriametrics` |
| Analitico | `clickhouse` |
| Grafo | `neo4j` |
| Mensajeria / streaming | `kafka` · `nats` · `rabbitmq` · `pulsar` |
| Coordinacion | `etcd` · `zookeeper` · `temporal` |
| Observabilidad | `prometheus` · `grafana` · `loki` · `tempo` · `otel-collector` · `vector` · `fluent-bit` |
| Gateways / proxies | `nginx` · `caddy` · `traefik` · `haproxy` |
| Almacenamiento de objetos | `garage` · `rustfs` · `seaweedfs` |
| Secretos / identidad | `openbao` · `keycloak` |
| Registro · Git · CI/IaC | `harbor` · `gitea` · `atlantis` |

⚠️ = source-available, **no** es codigo abierto aprobado por OSI (consulta [licencias](#una-nota-sobre-las-licencias)).

## Verifica un chart

```bash
cosign verify ghcr.io/quenchworks/charts/postgresql@sha256:DIGEST \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Documentacion por chart

GitHub muestra este unico README del repositorio en la pagina de paquete de cada chart; no puede renderizar un README por chart para artefactos OCI. La documentacion propia de cada chart (values, ejemplos, notas de seguridad) vive en **ArtifactHub** y se incluye dentro del propio chart:

```bash
helm show readme oci://ghcr.io/quenchworks/charts/<chart>
```

## Estructura

```
quench/<app>/             one app chart per directory, e.g. quench/postgresql
.github/workflows/        release (lint, install, package, push) and digest repin
```

El library chart compartido `quench-common` vive en su propio repositorio, [quenchworks/common](https://github.com/quenchworks/common), publicado en `oci://ghcr.io/quenchworks/charts/quench-common`. Los charts de aplicacion dependen de el y lo descargan en tiempo de construccion, asi que no esta vendorizado aqui.

## Como funcionan los releases

La fabrica de imagenes construye y firma una imagen, luego dispara un dispatch `image-published` a este repositorio. `on-digest.yml` vuelve a fijar el `values.yaml` del chart al nuevo digest y hace commit. Ese push activa `release-<app>.yml`, que ejecuta lint, templating, instala en un cluster de kind y ejecuta un roundtrip real de cliente como barrera, luego empaqueta y publica el chart OCI firmado con cosign y publica los metadatos de ArtifactHub.

## La regla clean-room

Los charts aqui se escriben a partir de la documentacion upstream propia de cada aplicacion. No se copian ni adaptan de los charts de ningun otro proveedor. Consulta [CONTRIBUTING](https://github.com/quenchworks/.github/blob/main/CONTRIBUTING.md).

## Una nota sobre las licencias

La mayor parte del catalogo es OSI-clean. Cuatro charts envuelven almacenes de datos source-available y llevan un banner de licencia destacado en su README, NOTES y en el sitio web, porque estos **no** son codigo abierto aprobado por OSI. Cada uno nombra la alternativa limpia que recomendamos en su lugar:

| Chart | Licencia | Alternativa limpia |
|-------|---------|-------------------|
| `mongodb` | SSPL-1.0 | `ferretdb` + `documentdb` (MongoDB-wire compatible, truly open) |
| `elasticsearch` | SSPL-1.0 | `opensearch` (Apache-2.0 drop-in fork) |
| `cockroachdb` | BUSL-1.1 | `postgresql` for single-region SQL (BUSL converts to Apache after 3 years) |
| `dragonfly` | BUSL-1.1 | `valkey` (BSD-3-Clause, Redis-compatible) |

## Licencia

MIT para las plantillas de chart y las herramientas. Cada aplicacion desplegada lleva su propia licencia upstream.
