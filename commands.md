# 🔍 Guia de Verificação de Configurações Kubernetes

> Referência completa para diagnosticar e validar todos os componentes de um cluster K8s via `kubectl`.

---

## 📋 Índice

1. [Diagnóstico Geral](#diagnóstico-geral)
2. [Control Plane](#control-plane)
3. [Nodes](#nodes)
4. [Pods](#pods)
5. [Virtual Network / CNI](#virtual-network--cni)
6. [Services](#services)
7. [Ingress](#ingress)
8. [ConfigMap e Secret](#configmap-e-secret)
9. [Volumes / PersistentVolume](#volumes--persistentvolume)
10. [Deployments e StatefulSets](#deployments-e-statefulsets)
11. [Diagnóstico Rápido Geral](#-diagnóstico-rápido-geral)
12. [Ferramentas Complementares](#-ferramentas-complementares)

---

## Diagnóstico Geral

```bash
# Versão e conectividade com o API Server
kubectl version

# Informações gerais do cluster (API Server, CoreDNS, etc.)
kubectl cluster-info

# Estado geral de todos os recursos
kubectl get all -A
```

---

## Control Plane

O Control Plane é responsável por gerenciar o cluster. Em clusters criados com `kubeadm`, seus componentes rodam como Pods estáticos no namespace `kube-system`.

```bash
# Status dos componentes do Control Plane
# (deprecado no 1.19+, mas ainda funciona em muitos clusters)
kubectl get componentstatuses

# Pods do control plane no namespace kube-system
kubectl get pods -n kube-system

# Filtrar apenas os componentes principais
kubectl get pods -n kube-system | grep -E "apiserver|controller|scheduler|etcd"

# Logs de um componente específico (ex: scheduler)
kubectl logs -n kube-system kube-scheduler-<node-name>

# Logs do etcd
kubectl logs -n kube-system etcd-<node-name>

# Logs do controller-manager
kubectl logs -n kube-system kube-controller-manager-<node-name>
```

### O que verificar

| Componente | Sinal de saúde |
|---|---|
| API Server | Pod em `Running`, sem crashloops |
| Controller Manager | Pod em `Running`, logs sem erros |
| Scheduler | Pod em `Running`, pods sendo alocados normalmente |
| etcd | Pod em `Running`, sem erros de quorum |

---

## Nodes

```bash
# Listar todos os nodes e seu status (Ready/NotReady)
kubectl get nodes

# Listar com mais detalhes (IP, roles, versão)
kubectl get nodes -o wide

# Detalhes completos de um node: recursos, condições, taints, eventos
kubectl describe node <node-name>

# Verificar pressão de recursos (memória, disco, PID)
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.conditions[-1].type,\
MEM_PRESSURE:.status.conditions[1].reason,\
DISK_PRESSURE:.status.conditions[0].reason

# Uso real de CPU e memória por node (requer Metrics Server)
kubectl top nodes
```

### Condições importantes no `describe node`

| Condição | Valor saudável |
|---|---|
| `Ready` | `True` |
| `MemoryPressure` | `False` |
| `DiskPressure` | `False` |
| `PIDPressure` | `False` |
| `NetworkUnavailable` | `False` |

---

## Pods

```bash
# Listar todos os pods em todos os namespaces
kubectl get pods -A

# Listar com IPs e nodes de execução
kubectl get pods -A -o wide

# Pods com problemas (não Running ou não Completed)
kubectl get pods -A | grep -vE "Running|Completed"

# Detalhes completos de um pod (eventos, volumes, IPs, condições)
kubectl describe pod <pod-name> -n <namespace>

# Logs do container
kubectl logs <pod-name> -n <namespace>

# Logs de container que já crashou
kubectl logs <pod-name> -n <namespace> --previous

# Logs de um container específico em pod com múltiplos containers
kubectl logs <pod-name> -n <namespace> -c <container-name>

# Acompanhar logs em tempo real
kubectl logs -f <pod-name> -n <namespace>

# Executar comando dentro do pod para diagnóstico
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh
```

### Status comuns e o que significam

| Status | Significado |
|---|---|
| `Running` | ✅ Saudável |
| `Completed` | ✅ Job finalizado com sucesso |
| `Pending` | ⚠️ Aguardando agendamento (checar recursos ou PVC) |
| `CrashLoopBackOff` | ❌ Container crashando repetidamente (checar logs) |
| `ImagePullBackOff` | ❌ Falha ao baixar a imagem (checar nome/tag/credenciais) |
| `OOMKilled` | ❌ Container encerrado por falta de memória |
| `Evicted` | ❌ Pod removido por pressão de recursos no node |

---

## Virtual Network / CNI

O CNI (Container Network Interface) garante que cada Pod tenha um IP único e que a comunicação Pod-to-Pod funcione sem NAT.

```bash
# Verificar se o plugin CNI está rodando
kubectl get pods -n kube-system | grep -E "calico|flannel|cilium|weave"

# Confirmar que cada pod tem IP atribuído
kubectl get pods -A -o wide

# Testar comunicação Pod-to-Pod (ping)
kubectl exec -it <pod-a> -n <namespace> -- ping <ip-do-pod-b>

# Testar resolução de DNS interno
kubectl exec -it <pod-a> -n <namespace> -- nslookup kubernetes.default

# Testar DNS de um service específico
kubectl exec -it <pod-a> -n <namespace> -- nslookup <service-name>.<namespace>.svc.cluster.local

# Verificar CoreDNS (responsável pelo DNS interno)
kubectl get pods -n kube-system | grep coredns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

### Sinais de problema no CNI

- Pod sem IP atribuído (`<none>` na coluna IP)
- Pods `Pending` sem node atribuído
- Falha em ping entre pods de nodes diferentes
- CoreDNS em `CrashLoopBackOff`

---

## Services

O Service fornece um IP virtual (ClusterIP) e DNS estáveis para um conjunto de Pods, abstraindo a efemeridade dos IPs dos Pods.

```bash
# Listar todos os services com ClusterIP e portas
kubectl get svc -A

# Detalhes de um service (endpoints, selector, tipo)
kubectl describe svc <service-name> -n <namespace>

# Verificar os Endpoints vinculados ao service
kubectl get endpoints <service-name> -n <namespace>

# Se Endpoints estiver vazio (<none>), o selector não bate com nenhum pod
# Verificar os labels dos pods e compará-los com o selector do service
kubectl get pods -n <namespace> --show-labels
kubectl get svc <service-name> -n <namespace> -o jsonpath='{.spec.selector}'

# Testar acesso ao service por dentro do cluster
kubectl exec -it <pod> -n <namespace> -- curl http://<service-name>.<namespace>.svc.cluster.local

# Testar acesso por ClusterIP diretamente
kubectl exec -it <pod> -n <namespace> -- curl http://<cluster-ip>:<port>
```

### ⚠️ Problema mais comum: Endpoints vazios

```bash
# 1. Ver o selector do service
kubectl get svc <service-name> -n <namespace> -o yaml | grep -A5 selector

# 2. Ver os labels dos pods
kubectl get pods -n <namespace> --show-labels

# 3. Confirmar que os labels batem — se não baterem, o service não roteia para nenhum pod
```

---

## Ingress

O Ingress declara regras de roteamento HTTP/HTTPS. O Ingress Controller (NGINX, Traefik, etc.) é quem implementa essas regras de fato.

```bash
# Listar Ingress com hosts e paths configurados
kubectl get ingress -A

# Detalhes das regras de roteamento
kubectl describe ingress <ingress-name> -n <namespace>

# Verificar se o Ingress Controller está rodando
kubectl get pods -A | grep -E "ingress|nginx|traefik|haproxy"

# Logs do Ingress Controller NGINX
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller

# Verificar o service do Ingress Controller (deve ter EXTERNAL-IP se LoadBalancer)
kubectl get svc -n ingress-nginx

# Verificar IngressClass configurada
kubectl get ingressclass
```

### O que verificar

- O Ingress Controller está em `Running`
- O service do controller tem `EXTERNAL-IP` atribuído (se tipo `LoadBalancer`)
- As regras do Ingress apontam para services existentes
- A `ingressClassName` no Ingress bate com o controller disponível

---

## ConfigMap e Secret

```bash
# --- ConfigMap ---

# Listar ConfigMaps
kubectl get configmap -A

# Ver conteúdo de um ConfigMap
kubectl describe configmap <name> -n <namespace>

# Ver em YAML completo
kubectl get configmap <name> -n <namespace> -o yaml

# --- Secret ---

# Listar Secrets
kubectl get secret -A

# Ver tipos e tamanhos (valores ficam ocultos)
kubectl describe secret <name> -n <namespace>

# Decodificar um valor específico de um Secret
kubectl get secret <name> -n <namespace> -o jsonpath='{.data.<chave>}' | base64 -d

# Decodificar todos os valores de um Secret
kubectl get secret <name> -n <namespace> -o json \
  | jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'

# --- Verificar consumo nos Pods ---

# Confirmar que o Pod está injetando ConfigMap/Secret corretamente
kubectl describe pod <pod-name> -n <namespace> | grep -A10 -E "Environment|Mounts|Volumes"
```

### ⚠️ Segurança: Secrets no etcd

Por padrão, Secrets são armazenados **sem criptografia** no etcd. Recomendações:

- Habilitar **Encryption at Rest** no Kubernetes
- Usar **Sealed Secrets** (Bitnami) ou **HashiCorp Vault** para gerenciamento externo

---

## Volumes / PersistentVolume

```bash
# Listar PersistentVolumes (recurso de nível de cluster)
kubectl get pv

# Listar PersistentVolumeClaims por namespace
kubectl get pvc -A

# Detalhes de um PVC (eventos, storage class, capacidade)
kubectl describe pvc <pvc-name> -n <namespace>

# Verificar StorageClasses disponíveis no cluster
kubectl get storageclass

# Verificar se o Pod está com o volume montado corretamente
kubectl describe pod <pod-name> -n <namespace> | grep -A10 Volumes
```

### Status do PVC

| Status | Significado |
|---|---|
| `Bound` | ✅ PVC vinculado a um PV com sucesso |
| `Pending` | ⚠️ Sem PV disponível ou StorageClass não provisiona dinamicamente |
| `Lost` | ❌ PV subjacente foi deletado ou ficou indisponível |

---

## Deployments e StatefulSets

```bash
# --- Deployments ---

# Ver status dos Deployments (READY, UP-TO-DATE, AVAILABLE)
kubectl get deployments -A

# Detalhes: histórico de rollout, eventos, réplicas
kubectl describe deployment <name> -n <namespace>

# Acompanhar rollout em tempo real
kubectl rollout status deployment/<name> -n <namespace>

# Histórico de versões do Deployment
kubectl rollout history deployment/<name> -n <namespace>

# Ver detalhes de uma revisão específica
kubectl rollout history deployment/<name> -n <namespace> --revision=<número>

# Rollback para a versão anterior
kubectl rollout undo deployment/<name> -n <namespace>

# Rollback para uma revisão específica
kubectl rollout undo deployment/<name> -n <namespace> --to-revision=<número>

# Escalar réplicas manualmente
kubectl scale deployment <name> -n <namespace> --replicas=<número>

# --- StatefulSets ---

# Listar StatefulSets
kubectl get statefulset -A

# Detalhes do StatefulSet
kubectl describe statefulset <name> -n <namespace>

# Verificar Pods do StatefulSet (devem ter nomes sequenciais: pod-0, pod-1, ...)
kubectl get pods -n <namespace> | grep <statefulset-name>

# Verificar PVCs criados por cada réplica do StatefulSet
kubectl get pvc -n <namespace> | grep <statefulset-name>
```

### Colunas do `kubectl get deployments`

| Coluna | Significado |
|---|---|
| `READY` | Pods prontos / total desejado |
| `UP-TO-DATE` | Pods atualizados com a última versão |
| `AVAILABLE` | Pods disponíveis para receber tráfego |

---

## 🩺 Diagnóstico Rápido Geral

Execute em sequência para ter uma visão rápida da saúde do cluster:

```bash
# Pods com problemas
kubectl get pods -A | grep -vE "Running|Completed|Terminating"

# Nodes não prontos
kubectl get nodes | grep -v " Ready"

# PVCs não vinculados
kubectl get pvc -A | grep -v Bound

# Deployments com réplicas insuficientes (desejado ≠ disponível)
kubectl get deployments -A | awk 'NR==1 || $3 != $4'

# Services sem endpoints (selector não bate com nenhum pod)
kubectl get endpoints -A | grep "<none>"

# Eventos de erro recentes no cluster inteiro
kubectl get events -A --sort-by='.lastTimestamp' | grep -iE "warning|error|failed|backoff"

# Resumo de uso de recursos (requer Metrics Server)
kubectl top nodes
kubectl top pods -A
```

---

## 🛠 Ferramentas Complementares

| Ferramenta | Finalidade | Instalação |
|---|---|---|
| **k9s** | TUI interativa para navegar o cluster em tempo real | `brew install k9s` |
| **stern** | Logs de múltiplos pods simultaneamente com filtros | `brew install stern` |
| **kubescape** | Audit de segurança e conformidade (NSA, MITRE) | `brew install kubescape` |
| **Lens** | IDE visual para Kubernetes (desktop) | [k8slens.dev](https://k8slens.dev) |
| **Metrics Server** | Habilita `kubectl top` para CPU e memória | `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml` |

---

> **Dica:** Crie um alias para agilizar o dia a dia:
> ```bash
> alias k=kubectl
> alias kga='kubectl get all -A'
> alias kgp='kubectl get pods -A'
> alias kge='kubectl get events -A --sort-by=.lastTimestamp'
> ```
