
oc create -f ./workloadpriority.yml
oc create -f ./team-a-ns.yaml -f ./team-b-ns.yaml
oc create -f ./team-a-rb.yaml -f ./team-b-rb.yaml
oc create -f ./default-flavor.yaml -f ./gpu-flavor.yaml
oc create -f ./team-a-cq.yaml -f ./team-b-cq.yaml -f ./shared-cq.yaml
oc create -f ./team-a-local-queue.yaml -f ./team-b-local-queue.yaml
