## Computación en la nube \- 0311AT – K8S: Casi como en producción

### Contexto 

Te sumás como ingeniero DevOps Jr. a un equipo de desarrollo de una pequeña empresa que necesita desplegar un entorno de trabajo para que el equipo de desarrollo pueda trabajar con la versión de contenido estático de su página web institucional. Como parte de tu primer trabajo, deberás confeccionar un entorno de trabajo en forma local en Minikube, con manifiestos de despliegue de aplicaciones, almacenamiento persistente y uso de Git y GitHub, y documentar todo el proceso con el objeto de pasarle dicha documentación al resto del equipo de desarrolladores de la empresa para que puedan trabajar en dicho entorno.  
Se debe de tener en cuenta que la aplicación debe poder servirse por navegador en forma local, con contenido propio (no el default de la plantilla), el cual estará alojado en un volumen persistente que se mantenga incluso si la aplicación se reinicia, pero que la misma debe estar vinculada al repositorio de git de su cuenta de Github.

### Crear estructura

- Paso 1: crea la carpeta que contendrá tu proyecto

```bash
mkdir proyecto-K8S
```

- Paso 2: Dentro de tu proyecto crea una carpeta para los manifiestos y otra para tu página web

```bash
cd proyecto-K8S
mkdir pagina-web
mkdir k8s-manifiestos
```


## Contenido web base

### Repositorio página web

- Paso 1: Se accede al repositorio original en GitHub, se hace click en el botón ***Fork*** y se elige la cuenta en la que vamos a alojar esta nueva copia

- Paso 2: En la terminal ,nos posicionamos en una carpeta local, en este caso la carpeta que creamos anteriormente ***pagina-web***, y la inicializamos como repositorio Git(repositorio vacío)

```bash
cd \proyecto-K8S\pagina-web
git init
```

- Paso 3: Se establece la conexión con el repositorio de GitHub

```bash
git remote add origin https://github.com/pauladist/static-website.git
```

- Paso 4: Para confirmar que la conexión, usamos el siguiente comando:

```bash
git remote -v
```

Nos debe mostrar las URLs asociadas al repositorio remoto de GitHub para ```fetch``` y ```push```

- Paso 5: Luego, se descargan los archivos existentes desde GitHub

```bash
git pull origin master  (o main, según tu repositorio)	
```

- Paso 6: Se modifica y personaliza la página web desde un editor de texto

- Paso 7: Se guardan los cambios, se registra un nuevo commit  y se sube al repositorio de GitHub

```bash
git add .
git commit -m "Personalización de la página web"
git push origin master
```

### Repositorio manifiestos

- Paso 1: Se crea un nuevo repositorio en GitHub, debe ser público

- Paso 2: En la terminal, nos posicionamos en una carpeta local, en este caso la carpeta que creamos anteriormente ***k8s-manifiestos***, y la inicializamos como repositorio Git(repositorio vacío)

```bash
cd \proyecto-K8S\k8s-manifiestos
git init
```

- Paso 3: Se establece la conexión con el repositorio de GitHub

```bash
git remote add origin https://github.com/pauladist/k8s-manifiestos.git
```


## Crear el entorno de kubernetes en Minikube

Posicionarse en la carpeta de manifiestos y crear las siguientes carpetas:

```bash
mkdir volumes
mkdir deployment
mkdir service
```

### Desplegar k8s en Minikube

Iniciamos minikube

```bash
minikube start --driver=docker --addons=ingress,dashboard,metrics-server
```

Verificamos que minikube esté funcionando

```bash
minikube status
```

### Crear PV y PVC

#### Paso 1: Crear los archivos

Posicionarse en la carpeta de volumes y crear 2 archivos yaml, uno para PersistentVolume y otro para PersistentVolumeClaim

```bash
cd \proyecto-K8S\k8s-manifiestos\volumes
New-Item -Path “pv.yaml” -ItemType “File”
New-Item -Path “pvc.yaml” -ItemType “File”
```

#### Paso 2: Definir el contenido de los archivos

Desde un editor de texto, abre los archivos que creaste y define su contenido, deberían verse así

- pv.yaml

```yaml
apiVersion: v1  
kind: PersistentVolume  
metadata:  
  name: pv-pagina-web  
spec:  
  capacity:  
    storage: 1Gi  
  accessModes:  
    - ReadWriteOnce  
  storageClassName: "standard"  
  hostPath:  
    path: "/home/docker/pagina-web"  
  persistentVolumeReclaimPolicy: Retain
```

- pvc.yaml

```yaml
apiVersion: v1  
kind: PersistentVolumeClaim  
metadata:  
  name: pvc-pagina-web  
spec:  
  accessModes:  
    - ReadWriteOnce  
  storageClassName: "standard"  
  resources:  
    requests:  
      storage: 1Gi
```

Importante\! 

- Para que ambos estén conectados entre sí deben tener el mismo ```accessModes``` y ```storageClassName```

#### Paso 3: Desplegar pv y pvc

Despliega cada volumen en el cluster de Minikube

```bash
kubectl apply -f pv.yaml
kubectl apply -f pvc.yaml
```

Puedes verificarlo, deberías ver a ambos con Status: ```Bound```

```bash
kubectl get pv  
kubectl get pvc
```

No te olvides de hacer los commits en git

```bash
git add pv.yaml pvc.yaml  
git commit -m “Creo y edito manifiestos PV y PVC”  
git push
```

### Crear Deployment

#### Paso 1: Crear el deployment

Posicionarse en la carpeta de deployments y crear el archivo despliegue.yaml 

```bash
cd \proyecto-K8S\k8s-manifiestos\deployments
kubectl create deployment ngnix --image=nginx --replicas=1 --dry-run=client -o yaml > despliegue.yaml
```

#### Paso 2: Definir el contenido del archivo

Desde tu editor de texto, abre el archivo que creaste y edita su configuración, debería verse así

```yaml
apiVersion: apps/v1  
kind: Deployment  
metadata:  
  labels:  
    app: nginx  
  name: nginx  
spec:  
  replicas: 1  
  selector:  
    matchLabels:  
      app: nginx  
  template:  
    metadata:  
      labels:  
        app: nginx  
    spec:  
      containers:  
      - image: nginx  
        name: nginx  
        ports:  
            - containerPort: 80  
        volumeMounts:  
            - name: pagina-web  
              mountPath: /usr/share/nginx/html  
        resources: {}  
      volumes:  
        - name: pagina-web  
          persistentVolumeClaim:  
            claimName: pvc-pagina-web          
status: {}
```
Importante\! 

- Para que el deployment pueda vincularse al PVC creado anteriormente añadimos ```volumes``` donde definimos el volumen ```pagina-web``` que se asocia con tu ```claimName: pvc-pagina-web```  
- En ```volumeMounts``` debes montar el volumen en ```/usr/share/nginx/html```, que es donde Nginx busca los archivos estáticos dentro del contenedor

#### Paso 3: Desplegar Deployment

Despliega Deployment en el cluster de Minikube
```bash
kubectl apply -f despliegue.yaml
```
Puedes verificar que se haya creado correctamente
```bash
kubectl get deployments  
kubectl get pods
```
No te olvides de hacer los commits en git
```bash
git add despliegue.yaml
git commit -m “Creo y edito manifiesto Deployment”
git push
```
### Crear Service

#### Paso 1: Crear el service

Posicionarse en la carpeta de services y crear el archivo service.yaml 

```bash
cd \proyecto-K8S\k8s-manifiestos\services
kubectl expose deployment ngnix --dry-run=client -o yaml > service.yaml
```

#### Paso 2: Verificar el contenido del archivo

Desde tu editor de texto, abre el archivo que creaste, debería verse así

```yaml
apiVersion: v1  
kind: Service  
metadata:  
  creationTimestamp: null  
  labels:  
    app: nginx  
  name: nginx  
spec:  
  ports:  
  - port: 80  
    protocol: TCP  
    targetPort: 80  
  selector:  
    app: nginx  
status:  
  loadBalancer: {}
```

#### Paso 3: Desplegar Service

Despliega Service en el cluster de Minikube
```bash
kubectl apply -f service.yaml
```
Puedes verificar que se haya creado correctamente ejecuta
```bash
kubectl get service
```
No te olvides de hacer los commits en git
```bash
git add service.yaml
git commit -m “Creo el manifiesto Service”
git push
```
### Desplegar tu página web

Por último, le solicitamos a minikube que exponga el servicio
```bash
minikube service nginx
```
### Error\!

Si has seguido estos pasos, es muy probable que no te muestre tu página web, seguramente te muestra una página en blanco con el error ***403 Forbidden***

- Asegurate de que Nginx tenga los permisos adecuados para leer los archivos

```bash
minikube ssh
sudo chmod -R 755 /home/docker/pagina-web
```

  Escribe ```exit``` para volver a la terminal de Windows

- Ejecuta la siguiente línea, deberías ver si el pod está vacío  
    
```bash
kubectl exec nginx-868db7d94-mpg2k -- ls -la /usr/share/nginx/html/
```

#### Solución 1:

Esta solución es viable y útil para pruebas rápidas, se copia el contenido del directorio dentro del pod

```bash
kubectl cp ./index.html nginx-868db7d94-mpg2k:/usr/share/nginx/html/
kubectl cp ./style.css nginx-868db7d94-mpg2k:/usr/share/nginx/html/
kubectl cp ./assets nginx-868db7d94-mpg2k:/usr/share/nginx/html/
```

```bash
minikube service nginx
```

Limitaciones: 

- Si el pod se reinicia o recrea, los cambios se perderán  
- No es automático, por lo que si realizas cambios en los archivos locales, tendrás que ejecutar nuevamente kubectl cp

#### Solución 2:

Esta solución es más eficiente ya que te permite ver los cambios inmediatamente sin tener que reconstruir imágenes o ejecutar comandos de copia

- Paso 1: Para evitar conflictos se detiene el pod actual  
    
```bash
kubectl scale deployment nginx --replicas=0
```
    
- Paso 2: Abre una nueva terminal y ejecuta con la ruta ajustada según tu directorio  
    
```bash
minikube mount C:\Users\paudi\proyecto-K8S\pagina-web:/home/docker/pagina-web
```

  Importante\! Esta terminal debe permanecer abierta durante todo el desarrollo, si la cierras se detiene la sincronización


- Paso 3: Se reinicia el deployment  
    
```bash
kubectl scale deployment nginx --replicas=1
```
    
- Paso 4: Para acceder a la página web, debes configurar lo siguiente  
    
```bash
kubectl port-forward service/nginx 8080:80
```

- Paso 5: Vuelve a ejecutar  
    
```bash
minikube service nginx
```

### Resultado

Tu sitio web se puede visualizar en el navegador\!


