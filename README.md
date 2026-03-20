# Arquitetura Kubernetes

### Cluster
"Datacenter lógico" que reúne todos os recursos do K8s. É comúm existir mais de um cluster, principalmente para separar ambientes como `prd`, `hml` e `dev`. Por padrão, esses clusters são isolados e não se comunicam entre si, embora seja possível integrá-los por meio de rede ou APIs quando necessário.

---

### Control Plane
Conjunto de componentes responsáveis por gerenciar o cluster. Os componentes do Control Plane podem rodar em diferentes ambientes:

- Em **laboratórios**, podem estar no Node;
- Em **produção simples**, podem rodar em um servidor dedicado;
- Em **ambientes mais complexos**, podem ser distribuídos em vários servidores dedicados para garantir alta disponibilidade e redundância.

#### Componentes do Control Plane

| Componente | Descrição |
|---|---|
| **API Server** | Expõe a API do Kubernetes e recebe todas as requisições para gerenciar o cluster provenientes de UI, API e CLI (`kubectl`) |
| **Controller Manager** | Responsável por garantir que o estado atual do cluster corresponda ao estado desejado |
| **Scheduler** | Processo inteligente responsável por decidir em qual Node um Pod será executado, baseado em métricas de CPU, Memória, etc. |
| **etcd** | Banco de dados key-value que armazena todos os dados de configuração do cluster (Pods, Nodes, Deployments, etc.) |

---

### Node
Servidor (físico ou virtual) que faz parte do cluster e é responsável por executar os Pods. Um cluster pode conter um ou mais Nodes.

---

### Virtual Network
Rede virtual que interliga todos os Pods, Nodes, Services e containers do cluster. Implementada via plugins CNI (como Calico, Flannel ou Cilium), garante que cada Pod tenha um IP único e consiga se comunicar com qualquer outro Pod no cluster sem NAT.

---

### Kubelet
Agent instalado em cada Node que recebe instruções do Control Plane para gerenciar os Pods dentro do Node.

---

### Container
Cada Node possui diferentes containers onde os microserviços são implantados.
