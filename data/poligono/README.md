Esta pasta é o local esperado para os SHPs dos Códigos Postais (Fonte: Thierry).

Fonte de Download: https://addressforall-my.sharepoint.com/personal/thierry_addressforall_org/_layouts/15/onedrive.aspx?id=%2Fpersonal%2Fthierry%5Faddressforall%5Forg%2FDocuments%2FA4A%5FOperacao%5F20%2FImput%5FDados%2FMexico%2FCorreos%2F2022%2D12%2D13%5Fportal&ga=1
Comando de Extração: for file in *.zip; do unzip -o "" -d /mnt/dados/download/mexico/poligonos/; done

Os scripts em 'src/ingestion/poligono/' esperam que os SHPs estejam
localizados em: '/mnt/dados/download/mexico/poligonos/'
