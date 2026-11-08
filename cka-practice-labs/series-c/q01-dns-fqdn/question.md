# DNS: Service, headless Service and Pod FQDNs

Namespaces `lima-control` and `lima-workload` already exist. Deployment
`controller` reads the ConfigMap `dns-config` through `envFrom`.

Update ConfigMap `dns-config` in `lima-control` with the correct **FQDN** for
each entry:

1. `DNS_1`: Service `kubernetes` in namespace `default`
2. `DNS_2`: headless Service `department` in namespace `lima-workload`
3. `DNS_3`: Pod `section100` in namespace `lima-workload`, addressed through
   the headless Service `department`, so the name stays valid even if the Pod
   IP changes
4. `DNS_4`: a Pod with IP `1.2.3.4` in namespace `kube-system` (this Pod does
   not exist; only the DNS name format is required)

Then make the Deployment use the new values and verify from inside a
`controller` Pod that DNS_1, DNS_2 and DNS_3 resolve. DNS_3 must resolve to the
current IP of Pod `section100`.
