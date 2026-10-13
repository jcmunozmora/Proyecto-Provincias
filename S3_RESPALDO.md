# Respaldo S3 de archivos ignorados por git

Fecha: 2026-10-13. Destino: `s3://jcmunoz/github_data/Proyecto-Provincias/_gitignored/`

Rutas respaldadas (misma estructura de carpetas):
- 03_Outputs/Agroindustrial_Occidente
- 03_Outputs/Agua_Bosques_Turismo
- 03_Outputs/Area_Metropolitana
- 03_Outputs/Bioenergetica_Norte
- 03_Outputs/Cartama
- 03_Outputs/De_la_Paz
- 03_Outputs/Minero_Agroecologica
- 03_Outputs/Penderisco_Sinifana
- 03_Outputs/Rio_Grande
- 03_Outputs/San_Juan
- 03_Outputs/Turistica_Agroecologica
- 03_Outputs/_Comparativo
- 04_Docs/anexo_metodologico.aux
- 04_Docs/anexo_metodologico.fdb_latexmk
- 04_Docs/anexo_metodologico.fls
- 04_Docs/anexo_metodologico.log
- 04_Docs/anexo_metodologico.out
- 04_Docs/anexo_metodologico.toc
- 04_Docs/borradores/Agroindustrial_Occidente/Agroindustrial_Occidente_diagnostico.docx
- 04_Docs/borradores/Agua_Bosques_Turismo/Agua_Bosques_Turismo_diagnostico.docx
- 04_Docs/borradores/Area_Metropolitana/Area_Metropolitana_diagnostico.docx
- 04_Docs/borradores/Bioenergetica_Norte/Bioenergetica_Norte_diagnostico.docx
- 04_Docs/borradores/Cartama/Cartama_diagnostico.docx
- 04_Docs/borradores/De_la_Paz/De_la_Paz_diagnostico.docx
- 04_Docs/borradores/Minero_Agroecologica/Minero_Agroecologica_diagnostico.docx
- 04_Docs/borradores/Penderisco_Sinifana/Penderisco_Sinifana_diagnostico.docx
- 04_Docs/borradores/Rio_Grande/Rio_Grande_diagnostico.docx
- 04_Docs/borradores/San_Juan/San_Juan_diagnostico.docx
- 04_Docs/borradores/Turistica_Agroecologica/Turistica_Agroecologica_diagnostico.docx
- tests/referencia

Restaurar: `aws s3 sync s3://jcmunoz/github_data/Proyecto-Provincias/_gitignored/ .`
