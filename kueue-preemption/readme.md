# 소개

Kueue에서 워크로드에 우선순위를 지정하여 자원을 선점하는 방법을 보여드리겠습니다.

## 개요 
이 예에서는 자체 네임스페이스에서 작업하는 2개의 팀이 있습니다.

1. 팀 A와 B는 같은 코호트 에 속합니다
1. 두 팀은 할당량을 공유합니다.
1. 팀 A는 GPU에 액세스할 수 있지만 팀 B는 액세스할 수 없습니다.
1. 팀 A에서 만든 워크로드에는 운영 prod 수준의 우선순위가 적용되어, 다른 팀의 워크로드 보다 먼저 시작할 수 있습니다.

`P.S 우선순위는 워크로드 기준이므로 팀별로 우선순위를 정하는 방법은 공정 공유(Fair Sharing) 방법을 활용해야 합니다.`

### Kueue 구성 

[CPU/Memory](default-flavor.yaml) 와 [GPU](gpu-flavor.yaml) 리소스를 각각 관리하는 두 가지 ResourceFlavor 가 있습니다.

두 팀 모두 해당 네임스페이스와 연결된 개별 클러스터 대기열을 갖고 있습니다.


| Name                        | CPU | Memory (GB) | GPU 
| --------------------------- | --- | ----------- | ---
| [팀 A 클러스터큐](team-a-cq.yaml) | 0   | 0           | 4 
| [팀 B 클러스터큐](team-b-cq.yaml) | 0   | 0           | 0
| [공통 클러스터큐](shared-cq.yaml) | 10  | 64          | 0   

클러스터 큐에 연결하기 위해 네임스페이스에는 로컬 큐가 정의됩니다.

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  name: local-queue
  namespace: team-a
spec:
  clusterQueue: team-a-cq
```

Ray 클러스터가 정의되면 연관된 우선순위와 함께 로컬 큐에 제출됩니다.

```yaml
apiVersion: ray.io/v1
kind: RayCluster
metadata:
  labels:  
    kueue.x-k8s.io/queue-name: local-queue
    kueue.x-k8s.io/priority-class: dev-priority
```

### Ray 클러스터 구성

> 두 팀 모두 공유 할당량은 최대 10 CPU입니다.

| Name                                   | CPU | Memory (GB) | GPU 
| -------------------------------------- | --- | ----------- | ----
| [팀 A](team-a-ray-cluster-prod.yaml) | 10  | 24          | 4 
| [팀 B](team-b-ray-cluster-dev.yaml)  | 6   | 16          | 0


### 선점

팀 A 클러스터 큐에는 팀 B가 속한 낮은 우선순위의 워크로드를 선점할 수 있는 `borrowWithinCohort`가 정의되어 있습니다.

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: team-a-cq
spec:
  preemption:
    reclaimWithinCohort: Any
    borrowWithinCohort:
      policy: LowerPriority
      maxPriorityThreshold: 100
    withinClusterQueue: Never
```

팀 A의 워크로드 (Ray 클러스터)는 운영에 필요한 자원이 부족하므로 팀 B보다 먼저 실행됩니다.


## 데모 세팅

1. OpenShift AI Operator 설치

2. GPU 4개 이상인 클러스터 환경 필요

3. [옵션] Taint the GPU node
    ```bash
      oc adm taint nodes <gpu-node> nvidia.com/gpu=Exists:NoSchedule
    ```
4. Git clone the repo

    ```bash
    git clone https://github.com/kkphil83/acm
    cd acm/kueue/kueue-preemption
    ```

5. 환경 구성 쉘 스크립트 실행
  
    ```bash
    sh make-setup-kueue-preemption.sh
    ```

이 예제를 삭제하려면, 다음 명령어를 실행합니다.:
```bash
sh make-teardown-kueue-preemption.sh
```
> 경고. 위 설정 스크립트는 클러스터의 모든 클러스터큐와 리소스플레이버를 삭제합니다.

## 예제 기동

1. 팀 B의 Ray 클러스터를 생성합니다. Ray 클러스터가 실행될 때까지 기다립니다.
    ```bash
    oc create -f team-b-ray-cluster-dev.yaml
    ```

    ```bash
    $ oc get rayclusters -A
    NAMESPACE   NAME             DESIRED WORKERS   AVAILABLE WORKERS   CPUS   MEMORY   GPUS   STATUS   AGE
    team-b      raycluster-dev   2                 2                   6      16G      0      ready    70s

    $ oc get po -n team-b
    NAME                                           READY   STATUS    RESTARTS   AGE
    raycluster-dev-head-zwfd8                      2/2     Running   0          45s
    raycluster-dev-worker-small-group-test-4c85h   1/1     Running   0          43s
    raycluster-dev-worker-small-group-test-5k9j5   1/1     Running   0          43s
    ```

2. 팀 A의 Ray 클러스터를 생성합니다.
    ```bash
    oc create -f team-a-ray-cluster-prod.yaml
    ```

3. 팀 B Ray 클러스터는 일시 중단되었고 팀 A Ray 클러스터는 선점했기 때문에 실행 됩니다. 이 작업이 완료되기까지 몇십 초 정도 걸릴 수 있습니다. 

    ```bash
    $ oc get rayclusters -A
    NAMESPACE   NAME              DESIRED WORKERS   AVAILABLE WORKERS   CPUS   MEMORY   GPUS   STATUS      AGE
    team-a      raycluster-prod   2                 2                   10     24G      4      ready       75s
    team-b      raycluster-dev    2                                     6      16G      0      suspended   3m46s
    ```