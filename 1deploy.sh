#!/bin/bash
# Script de despliegue automático para trabajo 0311AT de Computación en la Nube
# Autor: Paula Distefano
# Versión: 1.0
# Fecha: 02/05/2025
# Descripción: Este script despliega una aplicación simple en un cluster de Kubernetes usando Minikube
# Uso:
# 	./deploy.sh [--clean]

# Configuración de fail-fast
set -e
set -o pipefail

# Separación de configuración y lógica
PAGINA_WEB_REPO="https://github.com/pauladist/static-website.git"
MANIFIESTOS_REPO="https://github.com/pauladist/k8s-manifiestos.git"
PROYECTO_DIR="$(pwd)/proyecto-K8S"
NGINX_DEPLOYMENT="nginx"
TEMP_LOG=$(mktemp)
TIMEOUT=60

# Función para verificar dependencias
check_dependencies() {
    local dependencies=("git" "kubectl" "minikube")
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: $cmd no está instalado. Por favor, instálalo primero."
            exit 1
        fi
    done
}

# Función para crear directorios con verificación de idempotencia
create_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "Directorio creado: $dir"
    else
        echo "El directorio ya existe: $dir"
    fi
}

# Verificar si un comando se ejecutó correctamente
check_result() {
    local status=$?
    local message="$1"
    if [ $status -eq 0 ]; then
        echo "✅ $message"
    else
        echo "❌ Error: $message"
        exit 1
    fi
}

# Esperar a que un pod esté listo
wait_for_pod() {
    local app_label="$1"
    local timeout="$2"
    local counter=0
    
    echo "Esperando a que el pod $app_label esté listo..."
    while [ $counter -lt "$timeout" ]; do
        if kubectl get pods -l app="$app_label" 2>/dev/null | grep -q "Running"; then
            local pod_name=$(kubectl get pods -l app="$app_label" -o jsonpath="{.items[0].metadata.name}")
            if kubectl get pod "$pod_name" -o jsonpath="{.status.containerStatuses[0].ready}" | grep -q "true"; then
                echo "✅ Pod $pod_name está listo"
                return 0
            fi
        fi
        sleep 1
        counter=$((counter+1))
    done
    
    echo "❌ Tiempo de espera agotado para pod con etiqueta $app_label"
    return 1
}

# Verificar si una página web está disponible
check_webpage() {
    local url="$1"
    local timeout="$2"
    local counter=0
    
    echo "Verificando acceso a la página web en $url..."
    
    # Intentar acceder a la página web
    while [ $counter -lt "$timeout" ]; do
        if curl -s "$url" | grep -q "html"; then
            echo "✅ Página web accesible en $url"
            return 0
        fi
        sleep 1
        counter=$((counter+1))
    done
    
    echo "❌ No se pudo acceder a la página web en $url"
    return 1
}

# Función para limpiar recursos anteriores (opcional)
clean_resources() {
    echo "Limpiando recursos anteriores..."
    kubectl delete deployment nginx --ignore-not-found
    kubectl delete service nginx --ignore-not-found
    kubectl delete pvc pvc-pagina-web --ignore-not-found
    kubectl delete pv pv-pagina-web --ignore-not-found
    echo "✅ Limpieza completa"
    exit 0
}

# Función principal
main() {
    # Si se pasa el parámetro --clean, se limpia el entorno
    if [[ "$1" == "--clean" ]]; then
        clean_resources
    fi

    echo "=== Iniciando despliegue del proyecto K8S ==="
    
    # Verificar dependencias
    check_dependencies
    
    # Crear estructura de directorios
    create_dir "$PROYECTO_DIR"
    create_dir "$PROYECTO_DIR/pagina-web"
    create_dir "$PROYECTO_DIR/k8s-manifiestos"
    create_dir "$PROYECTO_DIR/k8s-manifiestos/volumes"
    create_dir "$PROYECTO_DIR/k8s-manifiestos/deployment"
    create_dir "$PROYECTO_DIR/k8s-manifiestos/service"
    
    # Clonar el repositorio de la página web
    if [ ! -d "$PROYECTO_DIR/static-website" ]; then
    git clone "$PAGINA_WEB_REPO"
    check_result "Repositorio página web clonado"
    else
    echo "Repositorio ya clonado. Actualizando..."
    cd "$PROYECTO_DIR/static-website" && git pull
    check_result "Repositorio actualizado"
    fi

    # Copiar contenido de html al directorio montado
    cp -r "$PROYECTO_DIR/static-website/"* "$PROYECTO_DIR/pagina-web/"
    cp -r "$PROYECTO_DIR/static-website/"*/ "$PROYECTO_DIR/pagina-web/"
    check_result "Contenido del sitio copiado"    
    
    # Verificar si existe la carpeta html
    if [ -d "$PROYECTO_DIR/static-website/" ]; then
        mkdir -p "$PROYECTO_DIR/pagina-web"
        cp -r "$PROYECTO_DIR/static-website/"* "$PROYECTO_DIR/pagina-web/"
        check_result "Archivos copiados a carpeta montada"
    else
        echo "❌ Error: no se encontró la carpeta html en el repositorio clonado"
        exit 1
    fi

    # Verificar si la página web se descargó correctamente
    if [ ! -f "index.html" ]; then
        echo "❌ Error: No se encontró el archivo index.html"
        exit 1
    fi
    
    # Copiar contenido del sitio al directorio del volumen
    cp -r "$PROYECTO_DIR/static-website/"* "$PROYECTO_DIR/pagina-web/"
    cp -r "$PROYECTO_DIR/static-website/"*/ "$PROYECTO_DIR/pagina-web/"
    check_result "Contenido del sitio copiado"

    # Clonar manifiestos de Kubernetes si no existen
    if [ ! -d "$PROYECTO_DIR/k8s-manifiestos" ]; then
        echo "Clonando manifiestos de Kubernetes..."
        git clone "$MANIFIESTOS_REPO" "$PROYECTO_DIR/k8s-manifiestos"
        check_result "Repositorio de manifiestos clonado"
    else
        echo "El directorio $DIR_MANIFIESTOS ya existe. Omitiendo clonación."
    fi
    
    echo "Aplicando manifiestos de Kubernetes..."
    kubectl apply -f "$PROYECTO_DIR/k8s-manifiestos/volumes/"
    kubectl apply -f "$PROYECTO_DIR/k8s-manifiestos/deployment/"
    kubectl apply -f "$PROYECTO_DIR/k8s-manifiestos/service/"
    check_result "Manifiestos aplicados correctamente"

    # Iniciar Minikube si no está en ejecución
    if ! minikube status | grep -q "Running"; then
        echo "Iniciando Minikube..."
        minikube start --driver=docker --addons=ingress,dashboard,metrics-server
        check_result "Minikube iniciado"
    else
        echo "Minikube ya está en ejecución"
    fi
    
    # Desplegar PV y PVC
    kubectl apply -f "$PROYECTO_DIR/k8s-manifiestos/volumes/pv.yaml"
    check_result "PV desplegado"
    
    kubectl apply -f "$PROYECTO_DIR/k8s-manifiestos/volumes/pvc.yaml"
    check_result "PVC desplegado"
    
    # Verificar estado de PV y PVC
    if ! kubectl get pv pv-pagina-web | grep -q "Bound"; then
        echo "⚠️ Advertencia: El PV no está en estado Bound"
    fi
    
    if ! kubectl get pvc pvc-pagina-web | grep -q "Bound"; then
        echo "⚠️ Advertencia: El PVC no está en estado Bound"
    fi
    
    # Detener el deployment existente si existe
    if kubectl get deployment "$NGINX_DEPLOYMENT" &>/dev/null; then
        echo "Deteniendo deployment existente..."
        kubectl scale deployment "$NGINX_DEPLOYMENT" --replicas=0
        sleep 3
    fi
    
    # Montar el directorio de la página web en Minikube
    echo "Montando directorio de página web en Minikube..."
    # Intentar detener montajes existentes sin usar pkill
    ps -ef | grep "minikube mount" | grep -v grep | awk '{print $2}' | xargs kill 2>/dev/null || true
    
    # Iniciar el montaje en segundo plano
    nohup minikube mount "$PROYECTO_DIR/pagina-web:/home/docker/pagina-web" > "$TEMP_LOG" 2>&1 &
    MOUNT_PID=$!
    echo "Mount iniciado con PID: $MOUNT_PID"
    
    # Esperar un poco para que el montaje se establezca
    sleep 5
    
    # Dar permisos al directorio montado
    minikube ssh "sudo chmod -R 755 /home/docker/pagina-web" || true
    
    # Desplegar el deployment
    kubectl apply -f "$PROYECTO_DIR/k8s-manifiestos/deployment/despliegue.yaml"
    check_result "Deployment desplegado"
    
    # Esperar a que el pod esté listo
    wait_for_pod "nginx" "$TIMEOUT"
    
    # Verificar que el pod tiene acceso a los archivos de la página web
    POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")
    
    # Configurar port-forwarding en segundo plano
    echo "Configurando port-forwarding..."
    ps -ef | grep "kubectl port-forward" | grep -v grep | awk '{print $2}' | xargs kill 2>/dev/null || true
    
    # Iniciar port-forwarding en segundo plano
    nohup kubectl port-forward service/nginx 8080:80 > /dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    echo "Port-forwarding iniciado con PID: $PORT_FORWARD_PID"

    # Esperar a que esté accesible
    echo "Esperando a que http://localhost:8080 esté disponible..."
    for i in {1..10}; do
        if curl -s http://localhost:8080 | grep -qi "html"; then
            echo "✅ Port-forwarding configurado y accesible: http://localhost:8080"
            break
        fi
        sleep 1
    done

    # Abrir el navegador automáticamente (solo funciona si hay entorno gráfico)
    if command -v xdg-open &> /dev/null; then
        xdg-open http://localhost:8080
    elif command -v open &> /dev/null; then
        open http://localhost:8080
    elif command -v start &> /dev/null; then
        start http://localhost:8080
    else
        echo "ℹ️ No se pudo abrir automáticamente el navegador. Abrí http://localhost:8080 manualmente."
    fi

    # (Re)Aplicar el Service manualmente por si no se creó
    kubectl apply -f "$PROYECTO_DIR/k8s-manifiestos/service/service.yaml"
    check_result "Service desplegado"

    # Esperar a que el servicio esté disponible
    echo "Esperando a que el servicio 'nginx' esté disponible..."
    for i in {1..10}; do
        if kubectl get svc nginx &> /dev/null; then
            echo "✅ Servicio 'nginx' disponible"
            break
        fi
        sleep 2
    done

    # Exponer el servicio con minikube
    echo "Exponiendo el servicio con minikube..."
    MINIKUBE_URL=$(minikube service nginx --url)
    
    echo ""
    echo "✅ Despliegue completado con éxito"
    echo ""
    echo "Para acceder a la aplicación, utiliza cualquiera de estas opciones:"
    echo "1. http://localhost:8080 (port-forwarding)"
    echo "2. $MINIKUBE_URL (minikube service)"
    echo ""
    echo "Nota: Para visualizar la página web, mantén abierta esta terminal"
    echo "ya que el port-forwarding y el mount están corriendo en procesos de fondo."
}

# Ejecutar el script
main "$@"