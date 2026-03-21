# Arquitetura Kubernetes

### Cluster
"Datacenter lógico" que reúne todos os recursos do K8s. É comum existir mais de um cluster, principalmente para separar ambientes como `prd`, `hml` e `dev`. Por padrão, esses clusters são isolados e não se comunicam entre si, embora seja possível integrá-los por meio de rede ou APIs quando necessário.

---

### Control Plane
Conjunto de componentes responsáveis por gerenciar o cluster. Os componentes do Control Plane podem rodar em diferentes ambientes:
- Em **laboratórios**, podem estar dentro de um Node;
- Em **produção simples**, podem rodar em um servidor dedicado;
- Em **ambientes mais complexos**, podem ser distribuídos em vários servidores dedicados para garantir alta disponibilidade e redundância.

#### Componentes do Control Plane
| Componente | Descrição |
|---|---|
| **Kube Proxy** | Expõe a API do Kubernetes e recebe todas as requisições para gerenciar o cluster provenientes de UI, API e CLI (`kubectl`) |
| **Controller Manager** | Responsável por garantir que o estado atual do cluster corresponda ao estado desejado (definido nos manifests) |
| **Scheduler** | Processo inteligente responsável por decidir em qual Node um Pod será executado, baseado em métricas de CPU, Memória, etc. |
| **etcd** | Banco de dados key-value que armazena todos os dados de configuração do cluster (Pods, Nodes, Deployments, etc.) |

---

### Node
Servidor (físico ou virtual) que faz parte do cluster e é responsável por executar os Pods. Um cluster pode conter um ou mais Nodes.

---

### Node Network components
| Componente | Descrição |
|---|---|
| **Kube-Proxy** | É um componente que roda em cada Node e é responsável por fazer o roteamento de rede funcionar na prática. Quando você cria um Service com ClusterIP 10.96.0.1, esse IP não existe fisicamente em nenhuma interface de rede — é virtual. O kube-proxy é quem transforma esse IP virtual em regras reais no sistema operacional (via iptables ou ipvs) para que o tráfego chegue de fato nos Pods certos. |
| **CoreDNS** | É o servidor DNS interno do cluster. Ele é responsável por resolver nomes de Services e Pods para IPs. |

Como os dois se relacionam:
```
Requisição do Pod A para "meu-service.namespace.svc.cluster.local"
 ↓ pergunta "qual é o IP desse nome?" ao
CoreDNS 
 ↓ retorna
ClusterIP 10.96.0.50
 ↓ Pod A se conecta ao ClusterIP
kube-proxy (regras de iptables no Node)
 ↓ chega ao
Pod B (destino real)
```
---

### Node Storage components
| Componente | Descrição |
|---|---|
| **StorageClass** | Define como um volume persistente deve ser provisionado — é o "template" do armazenamento. Ela descreve o tipo de disco, o provedor e as configurações. |
| **PersistentVolume (PV)** | É o volume de fato — representa um disco real provisionado no cluster. Pode ser criado manualmente por um admin ou automaticamente pela StorageClass. |
| **PersistentVolumeClaim (PVC)** | É o pedido de armazenamento feito por um Pod. O Pod não acessa o PV diretamente — ele cria um PVC dizendo o quanto precisa e qual tipo, e o Kubernetes vincula esse PVC a um PV disponível. |

Como os três se relacionam:
```
Pod
 ↓ usa
PVC (pedido: "preciso de 10Gi")
 ↓ vincula a
PV (disco real de 10Gi)
 ↓ que anteriormente foi provisionado pela
StorageClass ("cria um EBS gp3 na AWS")
```
---

### Kubelet
Agent instalado em cada Node que recebe instruções do Control Plane para gerenciar os Pods dentro do Node.

---

### Pod
É a menor unidade de implantação do Kubernetes: uma abstração que encapsula um ou mais containers (na prática, geralmente apenas um), compartilhando rede, armazenamento e configurações de execução, permitindo que o Kubernetes gerencie todos os containers do Pod como uma única unidade.

---

### Container
Aplicação empacotada em uma imagem com tudo que ela precisa para rodar — código, bibliotecas, dependências e configurações — em um ambiente isolado e portátil.

---

### Container Runtime
O container runtime (containerd, CRI-O ou Docker Engine) é o componente responsável por executar os containers em um Node. O fluxo é:
- O kubelet recebe a especificação dos Pods do Control Plane (via API Server).
- Verifica o estado atual dos containers do Pod no Node.
- Instrui o container runtime a criar, parar ou reiniciar os containers para convergir ao estado especificado no Pod.

---

### Virtual Network
Rede virtual que interliga todos os Pods, Nodes, Services e containers do cluster. Implementada via plugins CNI (como Calico, Flannel ou Cilium), garante que cada Pod tenha um IP único e consiga se comunicar com qualquer outro Pod no cluster sem NAT.

#### Pod-to-Pod
- Cada Pod recebe um IP único dentro do cluster.
- A comunicação entre Pods é viabilizada por plugins CNI (como Calico, Flannel ou Cilium), que configuram as interfaces de rede e as rotas necessárias.
- Exemplo de funcionamento: o Pod A no Node 1 envia um pacote TCP para o Pod B no Node 2.

#### Node-to-Node
- Cada Node possui um IP na rede subjacente do cluster.
- Essa camada é responsável por encaminhar pacotes entre Nodes, permitindo que Pods em Nodes diferentes se comuniquem.
- Esse roteamento é transparente para os Pods, que endereçam a comunicação exclusivamente pelos IPs dos próprios Pods.

---

### Efemeridade
Os Pods são efêmeros por natureza — podem ser encerrados, recriados ou realocados a qualquer momento pelo Kubernetes. Quando um Pod é recriado, ele perde o IP anterior e recebe um novo, pois endereços IP não são preservados entre recriações.

---

### Service
Solução para o problema do IP efêmero dos Pods — o Service provisiona um IP virtual (ClusterIP) e um nome DNS estáveis para um conjunto de Pods que executam a mesma aplicação. Assim, para acessar esses Pods, basta endereçar o IP ou o DNS do Service, independentemente de recriações ou substituições dos Pods subjacentes. Isso funciona porque o ciclo de vida do Service é desacoplado do ciclo de vida dos Pods.

O Service também atua como load balancer, distribuindo as requisições entre os Pods disponíveis — porém, o critério padrão é round-robin, não o nível de ocupação de cada Pod.

---

### Ingress
Recurso do Kubernetes que declara as regras de roteamento HTTP/HTTPS — como encaminhar requisições externas para Services específicos dentro do cluster com base em host ou caminho (path).

### Ingress Controller
Componente responsável por implementar essas regras na prática, atuando como proxy reverso (ex: NGINX, Traefik ou HAProxy). Sem um Ingress Controller em execução no cluster, os recursos Ingress não têm efeito.

---

### ConfigMap
Recurso do Kubernetes para armazenar dados de configuração não sensíveis — como variáveis de ambiente, arquivos de configuração ou parâmetros de inicialização. Seu conteúdo é persistido no etcd (via API Server) e pode ser consumido pelos Pods de duas formas: montado como volume no sistema de arquivos do container ou injetado diretamente como variáveis de ambiente.

---

### Secret
Recurso do Kubernetes para armazenar dados sensíveis — como senhas, tokens e chaves de API. Segue a mesma lógica de consumo do ConfigMap (injeção como variável de ambiente ou montagem como volume), mas com restrições de acesso mais rigorosas via RBAC.

Os dados são codificados em Base64 por padrão, o que não representa nenhuma camada de segurança, pois Base64 é uma codificação reversível trivialmente. O etcd armazena esses valores sem criptografia por padrão, por isso recomenda-se habilitar Encryption at Rest no próprio Kubernetes ou adotar ferramentas externas como Sealed Secrets ou HashiCorp Vault.

---

### Volume
Recurso que anexa um armazenamento persistente a um Pod, contornando a efemeridade dos Pods — que por padrão perdem todos os dados ao serem recriados. Esse armazenamento é gerenciado de forma independente do ciclo de vida do Pod e pode residir dentro do cluster (disco local do Node) ou fora dele (como AWS EBS, Google Persistent Disk ou NFS).

---

### Deployment
Recurso do Kubernetes que gerencia o ciclo de vida de Pods de forma declarativa (O Controller Manager lê o que o Deployment declarou e fica em loop garantindo via Deployment Controller que isso aconteça no cluster). Suas responsabilidades principais são:
- **Criação e manutenção de réplicas** — garante que o número especificado de Pods esteja sempre em execução; se um Pod falhar, o Deployment recria automaticamente.
- **Atualização controlada** — ao atualizar a imagem ou configuração da aplicação, o Deployment executa uma *rolling update* por padrão, substituindo os Pods gradualmente para evitar indisponibilidade.
- **Rollback** — mantém o histórico de revisões, permitindo reverter para uma versão anterior em caso de falha.

---

### StatefulSet
Recurso do Kubernetes com função similar ao Deployment — gerencia a criação e manutenção de réplicas de Pods — mas projetado para aplicações *stateful*, ou seja, que dependem de identidade estável e armazenamento persistente dedicado, como bancos de dados e sistemas de cache (ex: PostgreSQL, MongoDB, Redis).

As diferenças centrais em relação ao Deployment são:
- **Identidade estável** — cada Pod recebe um nome fixo e previsível (ex: `pod-0`, `pod-1`) que é preservado entre recriações, ao contrário dos Pods de um Deployment, que recebem nomes aleatórios.
- **Volume dedicado por réplica** — cada Pod tem seu próprio Volume persistente, não compartilhado com os demais.
- **Ordem de criação e encerramento** — os Pods são iniciados e encerrados em ordem sequencial, o que é necessário para aplicações com relações de liderança ou dependência entre réplicas (ex: primary/replica em bancos de dados).

De fato, não é uma boa prática hospedar bancos de dados dentro do cluster Kubernetes — a complexidade operacional de gerenciar persistência, backups e replicação em um ambiente efêmero como o Kubernetes supera os benefícios. O recomendado é utilizar serviços gerenciados externos, como AWS RDS ou Google Cloud SQL.
