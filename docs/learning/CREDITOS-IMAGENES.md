# Créditos y procedencia de las ilustraciones de "Aprender"

Las tres imágenes de los módulos vienen de **Wikimedia Commons** y están **empaquetadas** en la app
(`mobile/assets/learning/img/`), no enlazadas. La razón es de uso: los módulos de reconocimiento se
consultan **en campo, frente al árbol y a menudo sin señal**, así que una imagen que dependa de la red
no sirve justo cuando más hace falta.

Empaquetarlas significa **redistribuirlas**, así que la atribución no es cortesía: es la condición de
la licencia. Cada módulo lleva el crédito **visible al pie de su imagen**, con la licencia enlazada.

## Las tres imágenes

| Archivo en el repo | Módulo | Original en Commons | Autoría | Licencia |
|---|---|---|---|---|
| `img/mezquite.jpg` | `mod_que_es` — ¿Qué es el mezquite? | [File:Mezquite.jpg](https://commons.wikimedia.org/wiki/File:Mezquite.jpg) | Renebeto | **Dominio público** |
| `img/paxtle-tillandsia-recurvata.jpg` | `mod_paxtle` — Reconocer el paxtle | [File:Heno (Tillandsia recurvata).jpg](https://commons.wikimedia.org/wiki/File:Heno_(Tillandsia_recurvata).jpg) | Juan Carlos Fonseca Mata | **CC BY-SA 4.0** |
| `img/cuscuta.jpg` | `mod_cuscuta` — Reconocer la cúscuta | [File:Cuscuta 02.jpg](https://commons.wikimedia.org/wiki/File:Cuscuta_02.jpg) | ShahadatHossain | **CC BY-SA 4.0** |

Texto de las licencias: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.es).

## Qué implica CC BY-SA 4.0 aquí

- **Atribución obligatoria:** autor, licencia y enlace a la licencia, visibles. Está en el pie de foto
  de cada módulo.
- **Share-alike:** la obra derivada de una imagen BY-SA debe llevar la misma licencia. Incluir la
  imagen **sin modificarla** dentro de la app es *agregación*, no obra derivada: **no cambia la
  licencia MIT del software** ni la CC BY 4.0 de los datos. Cada imagen sigue siendo BY-SA de su autor.
- ⚠️ **Si alguna imagen se recorta, retoca o se le superpone texto**, eso sí sería obra derivada y
  tendría que publicarse como BY-SA. Hoy no se modifica ninguna: solo se redimensionaron al descargarlas.

## Cómo se descargaron (para poder repetirlo)

Se pidieron por `Special:FilePath`, que redirige al archivo real y acepta un ancho. Se usa esa ruta y
no la de `upload.wikimedia.org` con hash (`/b/bf/…`) porque esta última puede cambiar.

```bash
curl -L -A "mezquite-ciencia-ciudadana/1.0 (contacto@rescatando-el-mezquite.org)" \
  -o docs/learning/img/cuscuta.jpg \
  "https://commons.wikimedia.org/wiki/Special:FilePath/Cuscuta_02.jpg?width=800"
```

Wikimedia pide un `User-Agent` descriptivo. Los paréntesis del nombre del paxtle van codificados
(`%28`/`%29`).

**Lo que se obtuvo** (medido con Pillow, no estimado):

| Archivo | Original en Commons | Descargado | Peso |
|---|---|---|---|
| `mezquite.jpg` | 960×600 · 196 KB | 960×600 | 196 KB |
| `paxtle-tillandsia-recurvata.jpg` | 6110×8147 · 11 MB | 960×1280 | 335 KB |
| `cuscuta.jpg` | 4160×2340 · 1.5 MB | 960×540 | 170 KB |
| | | **Total** | **~700 KB** |

Nota: se pidió `width=800` pero Commons sirvió 960 px (elige de sus tamaños ya generados). Se
conservó así: mejor resolución al mismo peso medido.

## Fuente única y copia

Igual que los `.md` de este directorio, las imágenes viven aquí como **fuente** y se copian a
`mobile/assets/learning/img/` para el bundle. Las dos copias deben ser idénticas; si se cambia una
imagen, hay que copiarla de nuevo.

`assets/learning/img/` está declarado **explícitamente** en `pubspec.yaml`: declarar `assets/learning/`
no incluye subcarpetas.
