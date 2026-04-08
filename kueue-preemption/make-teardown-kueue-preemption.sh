
oc delete -f ./team-a-ray-cluster-prod.yaml -f ./team-b-ray-cluster-dev.yaml
oc delete -f ./team-a-cq.yaml -f ./team-b-cq.yaml -f ./shared-cq.yaml
oc delete -f ./team-a-local-queue.yaml -f ./team-b-local-queue.yaml	
oc delete -f ./default-flavor.yaml -f ./gpu-flavor.yaml
oc delete -f ./team-a-rb.yaml -f ./team-b-rb.yaml
oc delete -f ./team-a-ns.yaml -f ./team-b-ns.yaml
oc delete -f ./workloadpriority.yml

echo "Deleting all clusterqueues"
oc delete clusterqueue --all --all-namespaces 

echo "Deleting all resourceflavors"
oc delete resourceflavor --all --all-namespaces 
	
