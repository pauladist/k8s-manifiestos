# Despliegue de aplicación

Esta guía está diseñada para realizarla desde Windows PowerShell, si estás en Linux o Ubuntu, existen y puedes usar otros comandos diferentes a los que yo utilicé.

## Estructura

El proyecto debe tener el contenido de la página web por un lado y los manifiestos por otro, las carpetas dentro de manifiestos son opcionales.  
Para poder posicionarnos y movernos entre la estructura usaremos ***cd*** \+ la ruta desde donde queremos ejecutar los comandos.

proyecto-K8S  
├───k8s-manifiestos  
│   ├───deployments  
│   │       despliegue.yaml  
│   │  
│   ├───services  
│   │       service.yaml  
│   │  
│   └───volumes  
│           pv.yaml  
│           pvc.yaml  
│  
└───pagina-web  
    │   index.html  
    │   style.css  
    │  
    └───assets  
	      imagenes

### Crear estructura

- Paso 1: crea la carpeta que contendrá tu proyecto

***mkdir proyecto-K8S***

- Paso 2: Dentro de tu proyecto crea una carpeta para los manifiestos y otra para tu página web, las demás las crearemos más adelante

***cd proyecto-K8S***  
***mkdir pagina-web***  
***mkdir k8s-manifiestos***

## Contenido web base

### Repositorio página web

Se realizó un Fork del repositorio original con el fin de trabajar sobre una copia personal sin modificar el contenido original.

- Paso 1: Se accede al repositorio original en GitHub, se hace click en el botón ***Fork*** y se elige la cuenta en la que vamos a alojar esta nueva copia

- Paso 2: En la terminal de Windows, PowerShell, nos posicionamos en una carpeta local, en este caso la carpeta que creamos anteriormente ***pagina-web***, y la inicializamos como repositorio Git(repositorio vacío)

***cd \\proyecto-K8S\\pagina-web***  
***git init***	

- Paso 3: Se establece la conexión con el repositorio de GitHub

***git remote add origin https://github.com/pauladist/static-website.git***

- Paso 4: Para confirmar que la conexión se haya configurado correctamente, usamos el siguiente comando, nos debe mostrar las URLs asociadas al repositorio remoto de GitHub para *fetch* y *push*  
    
  ![image1](https://github.com/user-attachments/assets/5124118e-5e8c-4318-bc71-d402abcccef0)

- Paso 5: Luego, se descargan los archivos existentes desde GitHub

***git pull origin master***  (o main, según tu repositorio)	

- Paso 6: Se modifica y personaliza la página web dentro del directorio local, en mi caso utilicé Visual Studio Code

- Paso 7: Se guardan los cambios, se registra un nuevo commit  y se sube al repositorio de GitHub

***git add .***  
***git commit \-m "Personalización de la página web"***  
***git push origin master***

### Repositorio manifiestos

- Paso 1: Se crea un nuevo repositorio en GitHub, debe ser público y podemos nombrarlo k8s-manifiestos

- Paso 2: En la terminal de Windows, nos posicionamos en una carpeta local, en este caso la carpeta que creamos anteriormente ***k8s-manifiestos***, y la inicializamos como repositorio Git(repositorio vacío)

***cd \\proyecto-K8S\\k8s-manifiestos***  
***git init***	

- Paso 3: Se establece la conexión con el repositorio de GitHub

***git remote add origin https://github.com/pauladist/k8s-manifiestos.git***

## Crear el entorno de kubernetes en Minikube

Posicionarse en la carpeta de manifiestos y crear las siguientes carpetas:

***mkdir volumes***  
***mkdir deployment***  
***mkdir service***

### Desplegar k8s en Minikube

Iniciamos minikube

***minikube start \--driver=docker \--addons=ingress,dashboard,metrics-server***

Verificamos que minikube esté funcionando  

![image2](https://github.com/user-attachments/assets/ab04ff29-d71c-434a-977a-8adb5b02674a)

### Crear PV y PVC

#### Paso 1: Crear los archivos

Posicionarse en la carpeta de volumes y crear 2 archivos yaml, uno para PersistentVolume y otro para PersistentVolumeClaim

***cd \\proyecto-K8S\\k8s-manifiestos\\volumes***

![image3](https://github.com/user-attachments/assets/1e68715c-d70d-483f-92cf-9b921169ebb7)

#### Paso 2: Definir el contenido de los archivos

Desde un editor de texto, en mi caso Visual Studio Code, abre los archivos que creaste y define su contenido, deberían verse así

- pv.yaml

![image4](https://github.com/user-attachments/assets/d55ffe6b-e18b-42f7-a569-529047f3643f)

- pvc.yaml

![image5](https://github.com/user-attachments/assets/439f62f8-3362-4aac-ad1c-04cf45cbaa09)

Importante\! 

- Para que ambos estén conectados entre sí deben tener el mismo *accessModes* y *storageClassName*  
- El PV define la ubicación física del almacenamiento (en este caso, un directorio en el host)  
- El PVC es la solicitud de ese almacenamiento que utilizará el pod

#### Paso 3: Desplegar pv y pvc

Despliega cada volumen en el cluster de Minikube

***kubectl apply \-f pv.yaml***  
***kubectl apply \-f pvc.yaml***

Puedes verificarlo, deberías ver a ambos con Status: *Bound*  

![image6](https://github.com/user-attachments/assets/8cdcbbab-f8c6-49fb-8727-b2561920beb6)

No te olvides de hacer los commits en git

***git add pv.yaml pvc.yaml***  
***git commit \-m “Creo y edito manifiestos PV y PVC”***  
***git push***

### Crear Deployment

#### Paso 1: Crear el deployment

Posicionarse en la carpeta de deployments y crear el archivo despliegue.yaml 

***cd \\proyecto-K8S\\k8s-manifiestos\\deployments***  
***kubectl create deployment ngnix \--image=nginx \--replicas=1 \--dry-run=client \-o yaml \> despliegue.yaml***

#### Paso 2: Definir el contenido del archivo

Desde tu editor de texto, abre el archivo que creaste y edita su configuración, debería verse así

![image7](https://github.com/user-attachments/assets/3f1e9f92-6cdb-42fc-9c1b-d7dd31354575)

Importante\! 

- Para que el deployment pueda vincularse al PVC creado anteriormente añadimos *volumes* donde definimos el volumen *pagina-web* que se asocia con tu *claimName: pvc-pagina-web*  
- En *volumeMounts* debes montar el volumen en */usr/share/nginx/html*, que es donde Nginx busca los archivos estáticos dentro del contenedor

#### Paso 3: Desplegar Deployment

Despliega Deployment en el cluster de Minikube

***kubectl apply \-f despliegue.yaml***

Puedes verificar que se haya creado correctamente, debería verse así

![image8](https://github.com/user-attachments/assets/3d8952da-97da-4838-9d0c-21ab28cd2fa4)

No te olvides de hacer los commits en git

***git add despliegue.yaml***  
***git commit \-m “Creo y edito manifiesto Deployment”***  
***git push***

### Crear Service

#### Paso 1: Crear el service

Posicionarse en la carpeta de services y crear el archivo service.yaml 

***cd \\proyecto-K8S\\k8s-manifiestos\\services***  
***kubectl expose deployment ngnix \--dry-run=client \-o yaml \> service.yaml***

#### Paso 2: Verificar el contenido del archivo

Desde tu editor de texto, abre el archivo que creaste, debería verse así

![image9](https://github.com/user-attachments/assets/49208033-6bdc-4e9e-8d74-f709a2b31713)

#### Paso 3: Desplegar Service

Despliega Service en el cluster de Minikube

***kubectl apply \-f service.yaml***

Puedes verificar que se haya creado correctamente, debería verse así

![image10](https://github.com/user-attachments/assets/2f82455f-2343-4901-9d9e-017a4d050ad0)

No te olvides de hacer los commits en git

***git add service.yaml***  
***git commit \-m “Creo el manifiesto Service”***  
***git push***

### Pruebas

Puedes verificar que todo está funcionando correctamente

![image11](https://github.com/user-attachments/assets/dcd9012d-3229-4448-b521-0d38fa9d7d36)
![image12](https://github.com/user-attachments/assets/05303bd2-565b-4e7b-97c5-d219b3965888)

En este caso, podemos ver que en el segundo comando que ejecutamos no hay salida, esto es porque el directorio del pod está vacío

![image13](https://github.com/user-attachments/assets/5d9244a6-3efc-4d56-ad12-da26da8b4267)

- PV

![image14](https://github.com/user-attachments/assets/571089e4-1b80-434c-8ae9-73ba4a9a8504)

- PVC

![image15](https://github.com/user-attachments/assets/63c146c4-e58a-4397-8bbf-114deabf1f26)

### Desplegar tu página web

Por último, le solicitamos a minikube que exponga el servicio

***minikube service nginx***

La consola debería mostrar lo siguiente y automáticamente abrir una pestaña del navegador con tu sitio web

![image16](https://github.com/user-attachments/assets/aaf0af15-c010-4c46-9889-c6249ba85cd2)

### Error\!

Si has seguido estos pasos, es muy probable que no te muestre tu página web, seguramente te muestra una página en blanco con el error ***403 Forbidden***

- Una de las razones de este error es que Nginx no tiene los permisos adecuados para leer los archivos, puedes arreglarlo ejecutando:

***minikube ssh***

***sudo chmod \-R 755 /home/docker/pagina-web***

  Se conecta a la máquina virtual de Minikube y cambia los permisos, luego de resolver esto escribí ***exit*** para volver a la terminal de Windows

- Otra de las razones de este error es que el directorio está vacío, los archivos HTML no están en la ubicación que especificamos en el PV  
    
***kubectl exec nginx-868db7d94-mpg2k \-- ls \-la /usr/share/nginx/html/***  
    
  Ejecutando esa línea deberías ver si el pod está vacío

#### Solución 1:

Esta solución es viable y útil para pruebas rápidas, se copia el contenido del directorio dentro del pod

***kubectl cp ./index.html nginx-868db7d94-mpg2k:/usr/share/nginx/html/***  
***kubectl cp ./style.css nginx-868db7d94-mpg2k:/usr/share/nginx/html/***  
***kubectl cp ./assets nginx-868db7d94-mpg2k:/usr/share/nginx/html/***

***minikube service nginx***

![image17](https://github.com/user-attachments/assets/da1c80e3-a537-4b54-876c-13aff2fca38f)

Limitaciones: 
- Si el pod se reinicia o recrea, los cambios se perderán
- No es automático, por lo que si realizas cambios en los archivos locales, tendrás que ejecutar nuevamente kubectl cp

#### Solución 2:

Esta solución es más eficiente ya que te permite ver los cambios inmediatamente sin tener que reconstruir imágenes o ejecutar comandos de copia

- Paso 1: Para evitar conflictos se detiene el pod actual  
    
***kubectl scale deployment nginx \--replicas=0***  
    
- Paso 2: Abre una nueva terminal y ejecuta con la ruta ajustada según tu directorio  
    
***minikube mount C:\\Users\\paudi\\proyecto-K8S\\pagina-web:/home/docker/pagina-web***

![image18](https://github.com/user-attachments/assets/93d70e89-38c1-4a8d-93ac-40dd89e7bd39)

Importante\! Esta terminal debe permanecer abierta durante todo el desarrollo, si la cierras se detiene la sincronización

- Paso 3: Se reinicia el deployment  
    
***kubectl scale deployment nginx \--replicas=1***  
    
- Paso 4: Para acceder a la página web, debes configurar lo siguiente  
    
***kubectl port-forward service/nginx 8080:80***  
    
  Este comando crea un túnel desde el puerto 8080 de tu máquina local hacia el puerto 80 del servicio dentro del clúster de Kubernetes, permitiéndote acceder a la aplicación web a través de [http://localhost:8080](http://localhost:8080) en tu navegador.

### Despliegue final

Ahora puedes modificar tus archivos locales de la página web(html, css) en tu editor, guardar los cambios y luego de recargar el sitio web, deberías ver los cambios inmediatamente.

***minikube service nginx***

![image19](https://github.com/user-attachments/assets/c4d756b4-37cb-4f27-b7ff-f276b3c065e4)
![image20](https://github.com/user-attachments/assets/4534f513-7809-4570-b25c-9f59e7e0ef5b)
