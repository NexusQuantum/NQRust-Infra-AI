---
name: nqrust-hypervisor
description: Operate a Hypervisor HCI cluster (KubeVirt VMs/VMIs, Longhorn storage, VM images, networks, backups, templates, nodes) from natural language by driving `kubectl` against the cluster via a kubeconfig. Discovers cluster facts at runtime (never from memory) and verifies every mutation with a follow-up read. Requires `kubectl` locally and a Hypervisor kubeconfig in the RantaiClaw workspace.
version: 0.1.0
tags: [hypervisor, hci, kubevirt, longhorn, kubectl, operations, day2]
---

# NQRust Hypervisor operations (Hypervisor HCI, via `kubectl`)

Comprehensive operator skill for a Hypervisor HCI cluster, driven entirely through
`kubectl`. Use this skill for ANYTHING about Hypervisor: virtual machines (VM/VMI), VM
images, volumes/storage (Longhorn), networks, nodes, backups, templates, cluster health,
or installing/rotating a kubeconfig. If a question touches Hypervisor, KubeVirt, or
Longhorn, this skill applies.

The cluster is whatever the configured kubeconfig points to — do NOT assume a fixed IP or
hostname. The API server address, node names, and versions can change between
environments; always discover them at runtime (see "Discover the cluster" below) instead
of hardcoding them.

## Tools
- name: shell
  kind: builtin

## GOLDEN RULES (read first, every time)
1. NEVER answer a Hypervisor question from memory, assumption, or a "plausible"
   guess. ALWAYS run the relevant `kubectl` command THIS turn and base the
   answer ONLY on its real stdout.
2. NEVER invent resource names, IPs, counts, specs, or statuses. If you did not
   see it in command output this turn, you do not know it. Made-up VM names like
   "server-dev-001" or fake IPs are a critical failure.
3. If a command errors, show the exact error text and stop — do not substitute a
   guessed answer.
4. Give ONE final answer. Do not state a number/list, retract it, and give a
   different one in the same reply.
5. Answer in the user's language. Do not emit Chinese, Russian, or other-language
   tokens unless the user used them.
6. Count literally: number of data rows in the output = the count. Report the
   list AND the count.
7. NEVER invent credentials or make config choices for the user. Before creating
   anything that needs a credential or a decision (a VM, an image, a network,
   etc.), ASK and confirm first — see "Gather requirements before creating".
   Don't silently pick a username, password, SSH key, network, or disk size.
8. NEVER claim a create/apply/delete/start/stop/patch succeeded unless you ran a
   VERIFY command THIS turn and saw the resource in the expected state. Running
   `kubectl apply` is NOT success — the apply can error, be rejected by a webhook,
   or the resource can fail to provision. Saying "VM is being created" / "done" /
   "successfully created" without a confirming `kubectl get` is a CRITICAL failure
   (it has misled users into thinking a VM exists when it does not).
9. If a kubectl command errors, is rejected, or exits non-zero: QUOTE the exact
   error text, state plainly that the action FAILED, give the likely cause, and
   stop. Do NOT report success, and do NOT fabricate a result from memory.
10. NAMING — in everything YOU write to the user (prose, summaries, tables, the names you
   give things) always call this the **Hypervisor**; NEVER write the word "Harvester". If
   the user says "Hypervisor" they mean THIS cluster — treat the two as identical and act on
   it. This is presentation ONLY: keep the real Kubernetes identifiers unchanged inside
   commands (`harvesterhci.io`, the `harvester-system` namespace, `harvester-webhook`, the
   `creator: harvester` label) — rewriting them breaks the command. When a real error or
   command output contains the literal token "harvester" (e.g. `service "harvester-webhook"`),
   quote it EXACTLY (rules 8-9), then describe it in your own words as the Hypervisor (e.g.
   "the Hypervisor admission webhook is down").

## Connection — how kubectl reaches the cluster
Every command MUST run with the Hypervisor kubeconfig in the `KUBECONFIG` env var. The
kubeconfig lives in the RantaiClaw **workspace** as `kubeconfig-hypervisor`. Resolve its
path portably (works for any user/profile) and export it ONCE at the start of a shell
session so you can't forget it:

```
export KUBECONFIG="${KUBECONFIG:-${RANTAICLAW_HOME:-$HOME/.rantaiclaw}/profiles/${RANTAICLAW_PROFILE:-default}/workspace/kubeconfig-hypervisor}"
```

After that, every command is just `kubectl <args>`. (RantaiClaw sets `RANTAICLAW_PROFILE`
for the active profile; if you run a non-default profile and the path is wrong, point
`KUBECONFIG` at the right `.../profiles/<profile>/workspace/kubeconfig-hypervisor`.)

- Do NOT add `--insecure-skip-tls-verify`. The kubeconfig's CA already verifies
  the server cert; the flag is unnecessary.
- Do NOT edit, regenerate, or "fix" `certificate-authority-data`. It is valid.
  Past failures came from corrupting it. If kubectl fails, fix the COMMAND, not
  the cert.
- The kubeconfig points DIRECTLY at one Hypervisor cluster. Never claim it points
  to a "different" / "downstream" / "management-plane" cluster.
- If `$KUBECONFIG` does not exist yet, the kubeconfig hasn't been installed — see
  "Installing / rotating a kubeconfig" below. Do NOT invent a path.

## Discover the cluster (do this instead of hardcoding facts)
When you need the server address, node names, or versions, read them live —
never type a remembered IP:

- API server URL:  `kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}{"\n"}'`
- Nodes + IPs:     `kubectl get nodes -o wide`
- Versions:        `kubectl version -o yaml | grep -i gitVersion` and
                   `kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.osImage}{"\n"}'`

## Installing / rotating a kubeconfig (when given a new one)
When the user hands you a new kubeconfig (downloaded from Rancher/Hypervisor UI →
cluster → "Download KubeConfig"), follow these steps exactly:

1. Point `KUBECONFIG` at the workspace location and save the file there (the only
   dir the agent may write):
   ```
   export KUBECONFIG="${RANTAICLAW_HOME:-$HOME/.rantaiclaw}/profiles/${RANTAICLAW_PROFILE:-default}/workspace/kubeconfig-hypervisor"
   cp <source-path> "$KUBECONFIG"      # or write the pasted YAML into "$KUBECONFIG"
   ```
2. Lock permissions: `chmod 600 "$KUBECONFIG"`
3. Validate the CA is intact base64 (must print `OK`):
   `kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d >/dev/null && echo OK`
4. Smoke-test connectivity WITHOUT the insecure flag:
   `kubectl get nodes -o wide`
   If that returns nodes, the kubeconfig is good and ready.
5. Secrets hygiene: a kubeconfig is a credential. Keep it only in the workspace
   with mode 600. NEVER print its token/CA in chat and NEVER commit it to git
   (add `kubeconfig*` to `.gitignore` if a repo is involved).

If validation step 3 fails ("illegal base64"), the file was corrupted in
transit — ask the user to re-download a fresh kubeconfig rather than trying to
hand-repair the cert.

## Read / inspect commands (prefer these; safe)
Resource short names in parentheses.

- Nodes & health:
  - `kubectl get nodes -o wide`
  - `kubectl get hrq -A`           # Hypervisor ResourceQuota
  - `kubectl get settings.harvesterhci.io`
- VM images (vmimage/vmimages):
  - `kubectl get virtualmachineimages.harvesterhci.io -A`
- Virtual machines (vm/vms):
  - `kubectl get virtualmachines.kubevirt.io -A`
  - `kubectl describe virtualmachine.kubevirt.io <name> -n <ns>`
- Running instances + IP/node (vmi/vmis):
  - `kubectl get virtualmachineinstances.kubevirt.io -A -o wide`
- VM templates: `kubectl get vmtemplate -A` / `kubectl get vmtemplateversion -A`
- Storage / volumes:
  - `kubectl get pvc -A`
  - `kubectl get volumes.longhorn.io -n longhorn-system`         # (lhv)
  - `kubectl get backingimages.longhorn.io -n longhorn-system`   # (lhbi)
  - `kubectl get sc`                                             # storage classes (per-image lh-* classes)
- Backups / snapshots:
  - `kubectl get vmbackup -A` ; `kubectl get vmrestore -A`
  - `kubectl get snapshots.longhorn.io -n longhorn-system`
- Networking:
  - `kubectl get network-attachment-definitions -A`   # VM networks (net-attach-def)
- SSH keypairs: `kubectl get keypairs.harvesterhci.io -A`   # (kp)
- Anything unknown: discover with
  `kubectl api-resources --api-group=harvesterhci.io` (also kubevirt.io,
  longhorn.io) then `kubectl get <name> -A`.

## Gather requirements before creating anything
Do NOT start building a manifest or running create/apply commands until you have
the user's explicit answers. Ask concise, batched questions first, echo back a
summary, and proceed only after the user confirms. Never fill gaps with invented
defaults — especially credentials.

For a VM, confirm at least:
- Name and namespace.
- vCPU, RAM, root disk size.
- Which image to clone from (list ready images and let the user pick).
- Login method: SSH public key (preferred — ask the user to provide it) OR a
  username + password. If password, ask the user to supply it; do NOT make one
  up. Ask whether SSH access is needed at all.
- Network — this is the #1 thing to confirm if SSH is wanted (see "Networking
  for SSH / LAN access" below). The pod network alone gives only an internal
  cluster IP that you CANNOT ssh to from a laptop. For SSH, a bridge interface
  on a NetworkAttachmentDefinition is required. ASK the user which network to
  attach (list the available NADs), and whether they want pod-only or bridge.
- Anything else relevant (extra disks, cloud-init packages, static IP, etc.).

If the user already gave some of these, only ask for what's missing. When every
required value is known, show the final summary + manifest, then apply after
confirmation. The same "ask first" rule applies to images (source URL),
networks, and any resource carrying a secret or a user-facing choice.

## Creating a VM (the Hypervisor-native pattern)
First complete "Gather requirements before creating anything" above. Then: a
Hypervisor VM clones its root disk from an existing VM image via a per-image
storage class. Build it dynamically — never hardcode image names or storage
class IDs; look them up first:

1. Pick a ready image and its storage class:
   `kubectl get virtualmachineimages.harvesterhci.io -n <ns> -o custom-columns='NAME:.metadata.name,SC:.status.storageClassName,PROGRESS:.status.progress'`
   (use one with PROGRESS=100; prefer a cloud image, e.g. `*-cloudimg-*`, so it
   boots straight to an OS and supports cloud-init).
2. Author a `VirtualMachine` manifest with:
   - annotation `harvesterhci.io/volumeClaimTemplates` defining the root PVC,
     including `annotations: harvesterhci.io/imageId: <ns>/<image-name>`,
     `storageClassName: <the lh-* class from step 1>`, `volumeMode: Block`,
     `accessModes: [ReadWriteMany]`, requested `storage` = desired disk size.
   - `domain.cpu` cores, `domain.memory.guest`, matching resource limits.
   - a `disk-0` (bus virtio, bootOrder 1) bound to that PVC, plus a
     `cloudinitdisk` (cloudInitNoCloud userData) for the login user.
   - network: see "Networking for SSH / LAN access" below. For internal-only,
     one pod-network interface (`masquerade: {}`) is enough. For SSH from the
     LAN, ALSO add a bridge interface on a NAD.
3. SHOW the manifest to the user, then `kubectl apply -f -` only after confirm.
4. Watch it: `kubectl get vm <name> -n <ns> -w` and
   `kubectl get vmi <name> -n <ns> -o wide` for the IP. For the LAN/bridge IP,
   confirm the guest got it: `kubectl get vmi <name> -n <ns> -o jsonpath='{range .status.interfaces[*]}{.name}{" -> "}{.ipAddress}{"\n"}{end}'`.

### Canonical VM manifest (this is the default shape — adapt the placeholders)
This is the proven, working template. By DEFAULT build a VM like this: cloud
image root disk + pod NIC + a bridge NIC (model virtio) on the user's chosen NAD
+ cloud-init `userData` (login) AND `networkData` (DHCP on BOTH NICs so the
bridge NIC actually gets a LAN IP — without networkData the second NIC stays DOWN
and is not SSH-able). Look up the image name + storage class (step 1) and the NAD
(ask the user) first; never hardcode the `lh-*` id or NAD blindly. If the user
explicitly wants internal-only / no SSH, drop the bridge NIC, its network, and
the `enp2s0` line from networkData.

```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: <vm-name>
  namespace: <ns>
  labels:
    harvesterhci.io/creator: harvester
    harvesterhci.io/os: linux
  annotations:
    harvesterhci.io/volumeClaimTemplates: '[{"metadata":{"name":"<vm-name>-disk-0","annotations":{"harvesterhci.io/imageId":"<ns>/<image-name>"}},"spec":{"accessModes":["ReadWriteMany"],"resources":{"requests":{"storage":"<size>Gi"}},"volumeMode":"Block","storageClassName":"<lh-* class from step 1>"}}]'
spec:
  runStrategy: RerunOnFailure        # use Always if it must auto-start after every stop
  template:
    metadata:
      labels:
        harvesterhci.io/vmName: <vm-name>
    spec:
      domain:
        cpu: { cores: <vcpu>, sockets: 1, threads: 1 }
        memory: { guest: <ram>Gi }
        resources:
          limits: { cpu: "<vcpu>", memory: <ram>Gi }
          requests: { cpu: 200m, memory: <~2/3 ram>Mi }
        devices:
          disks:
          - name: disk-0
            bootOrder: 1
            disk: { bus: virtio }
          - name: cloudinitdisk
            disk: { bus: virtio }
          interfaces:
          - name: default              # pod network (internal)
            masquerade: {}
            model: virtio
          - name: nic-lan              # bridge NIC for LAN/SSH (omit if internal-only)
            bridge: {}
            model: virtio
        machine: { type: q35 }
      networks:
      - name: default
        pod: {}
      - name: nic-lan                  # omit if internal-only
        multus:
          networkName: <ns>/<nad-name>   # the NAD the user chose
      volumes:
      - name: disk-0
        persistentVolumeClaim:
          claimName: <vm-name>-disk-0
      - name: cloudinitdisk
        cloudInitNoCloud:
          networkData: |
            version: 2
            ethernets:
              enp1s0: { dhcp4: true }
              enp2s0: { dhcp4: true }   # omit this line if internal-only
          userData: |
            #cloud-config
            user: <username from user>
            password: <password from user>
            chpasswd: { expire: false }
            ssh_pwauth: true
            # OR, preferred: ssh_authorized_keys: [ "<user's public key>" ]
            packages: [ qemu-guest-agent ]
            runcmd:
              - systemctl enable --now qemu-guest-agent
```

Guest NIC naming: the pod NIC is usually `enp1s0` and the bridge NIC `enp2s0`,
but verify from `ip a` / the console if DHCP doesn't land; adjust networkData
names to match.

## Networking for SSH / LAN access
A VM on the pod network only gets an internal cluster IP (e.g. 10.52.x.x) via
`masquerade`. You CANNOT ssh to that from outside the cluster. To make a VM
reachable (and SSH-able) on the LAN, it needs a SECOND network interface of
type **bridge** attached to a Hypervisor network (a
`NetworkAttachmentDefinition` / VM network), so it gets a routable IP.

ALWAYS ask the user which network to use — do not assume. Discover the options:
`kubectl get network-attachment-definitions -A` and inspect one with
`kubectl get net-attach-def <name> -n <ns> -o jsonpath='{.spec.config}{"\n"}'`
to see its `type` (bridge), `vlan`, and `ipam` (host-local range / dhcp / none).
A NAD with an `ipam` range or `dhcp` hands the VM a routable IP automatically; a
NAD with no ipam needs a static IP set via cloud-init.

The bridge interface pattern (mirrors how existing LAN-reachable VMs are wired)
— add to the VM template a second interface + matching network:

```yaml
domain:
  devices:
    interfaces:
    - name: nic-0          # pod network (optional to keep)
      masquerade: {}
      model: virtio
    - name: <free-name>    # the bridge NIC — ASK the user for intent
      bridge: {}
      model: virtio        # model virtio
networks:
- name: nic-0
  pod: {}
- name: <free-name>
  multus:
    networkName: <ns>/<nad-name>   # the NAD the user chose
```

After it boots, the bridge IP shows in `kubectl get vmi <name> -n <ns> -o wide`
(or inside the guest via `ip a`). SSH to THAT IP, not the pod IP.

IMPORTANT — the guest must bring the bridge NIC up itself. Adding the interface
at the KubeVirt level is NOT enough: Ubuntu/most cloud images only auto-configure
the FIRST NIC, so the second (bridge) NIC comes up DOWN with no IP and is not
SSH-able, even though KubeVirt/CNI are ready to DHCP it. Symptom: `ip a` in the
guest shows e.g. `enp2s0 ... state DOWN` and no `inet`, and
`kubectl get vmi ... -o jsonpath='{.status.interfaces[*].ipAddress}'` is empty
for that NIC. Fix: provide cloud-init `networkData` enabling DHCP on every NIC,
on the SAME cloudinit disk as userData:

```yaml
      - name: cloudinitdisk
        cloudInitNoCloud:
          networkData: |
            version: 2
            ethernets:
              enp1s0: { dhcp4: true }
              enp2s0: { dhcp4: true }
          userData: |
            #cloud-config
            ...
```

`networkData` is applied by cloud-init on FIRST boot of a new instance, so it
works cleanly on a freshly-created VM. For an ALREADY-running VM where the NIC
is DOWN, either (a) bring it up in-guest via the console:
`sudo dhclient enp2s0` (or write a netplan and `sudo netplan apply`), or
(b) recreate the VM with the networkData above. Confirm with the user before
recreating, since that deletes the current VM/disk.

To add SSH/bridge connectivity to an EXISTING VM, you must edit its interfaces
+ networks (a `kubectl edit vm` / patch) and reboot the VM — confirm with the
user first, then restart so the new NIC attaches.

## Mutating operations (CONFIRM before running)
For ANY create/delete/apply/scale/power action: first state in plain language
exactly what will change (which resource, which namespace), then run it only
after the user confirms.

- Start a VM:   `kubectl virt start <name> -n <ns>`  (or patch `spec.running=true`)
- Stop a VM:    `kubectl virt stop <name> -n <ns>`
- Restart a VM: `kubectl virt restart <name> -n <ns>`
  (if the `virt` plugin is absent, toggle the VM's `spec.runStrategy`/`running`
   field with `kubectl patch` instead.)
- Delete a VM:  `kubectl delete virtualmachine.kubevirt.io <name> -n <ns>`
- Console/serial: `kubectl virt console <name> -n <ns>` (interactive — only if
  the user explicitly wants a console session).
- Never apply a manifest the user hasn't seen.

### VERIFY AFTER every mutation (MANDATORY — do not skip)
A create/apply/power command is NOT done when it returns — it is done when a
follow-up read confirms it. After running the mutation, in the SAME turn:

1. Look at the command's own output. `kubectl apply` prints `<kind>/<name> created`
   / `configured` on success, or an `error: ...` / webhook rejection on failure.
   If you see an error or a non-zero exit, the action FAILED — quote the exact
   error, say it failed, give the likely cause, and STOP (golden rules 8-9).
2. Then re-query to confirm the new state, e.g. for a VM:
   `kubectl get vm <name> -n <ns> -o wide` and `kubectl get vmi <name> -n <ns> -o wide`.
   - Resource present with the expected status — report success, with the real
     name/status/IP/node from THAT output.
   - `NotFound` / empty / wrong state — it did NOT get created/changed. Say so
     plainly; do not claim success. Then diagnose (events, describe).
3. For a freshly-created VM also check it actually provisions, don't stop at
   "VM object exists": `kubectl get pvc -n <ns>` (the `<name>-disk-0` PVC must go
   Bound — a root disk smaller than the source image will leave it Pending/failed),
   and `kubectl describe vm <name> -n <ns>` / `kubectl get events -n <ns> --sort-by=.lastTimestamp | tail`
   for any rejection. Report the real state, not the intended one.

Common create pitfalls to check for and report honestly (never silently "succeed"):
- Root disk smaller than the source image's virtual size — PVC won't provision.
  Look up the image size first and ensure the requested disk is ≥ it.
- An ISO/installer image (e.g. `*-live-server-*`, `*.iso`) used as a cloud-init
  root disk — it boots an installer, cloud-init (user/password/SSH) does NOT
  apply. For a cloud-init / SSH VM you need a CLOUD image (e.g. `*-cloudimg-*`).
- Bridge NAD with no `ipam` — the guest only gets a LAN IP via external DHCP; if
  none is served the bridge NIC has no IP and is not SSH-able.

## Output & communication style
- Lead with the direct answer (the count or the list), then a short table.
- Tables for lists: include real Name, Status/Phase, IP, Node, Namespace as
  applicable — only columns you actually have from output.
- If the user asks "how many", give the number first, then the backing list.
- Offer a sensible next step (e.g. "lihat VM yang stop?", "detail volume?").
- When you ran a command, it's fine to note which kubectl you used; never claim
  to have used a tool you didn't, and never claim output you didn't get.

## Troubleshooting
- `error loading config file ... illegal base64` — kubeconfig file corrupted;
  re-install per the section above. Do NOT hand-edit the cert.
- `Unable to connect to the server` / timeout — cluster/API unreachable from
  this host; report it, don't fake data.
- `the server doesn't have a resource type "X"` — wrong resource name; list with
  `kubectl api-resources` and retry with the correct one.
- **Creating a VM fails with `no endpoints available for service "harvester-webhook"`
  (or `failed calling webhook validator.harvesterhci.io`)** — this is a CLUSTER
  problem, NOT a problem with your VM manifest. The Hypervisor admission webhook
  is down. Do NOT rewrite/retry the VM YAML and do NOT ask the user for
  "hypervisor credentials" — you already have full access via kubectl. Diagnose:
  - `kubectl get pods -n harvester-system | grep -E 'harvester-webhook|harvester-[0-9a-f]{6,}'`
  - Look for `ErrImagePull` / `ImagePullBackOff` / `CrashLoopBackOff`. A common
    cause is the `harvester`/`harvester-webhook` Deployment pointing at a
    non-existent image tag (e.g. a dev tag like `HEAD-head`) after a Helm/Fleet
    upgrade: `kubectl get deploy harvester harvester-webhook -n harvester-system -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{.spec.template.spec.containers[0].image}{"\n"}{end}'`
  - These are Fleet/Helm-managed control-plane components. Report the finding and
    let the user/admin decide the fix (roll back the Helm release / fix the Fleet
    managedchart). Do NOT patch system deployments without explicit confirmation.
  - The VM manifest is fine; it can be applied once the webhook is healthy
    (`harvester-webhook` pod `1/1 Running`).
- **VM created but stuck `Starting`/VMI `Scheduling`, never gets an IP, with
  `FailedCreatePodSandBox ... plugin type="multus" ... network "<nad>": cannot
  convert: no valid IP addresses`** — the VM and its disk are FINE; the bridge
  NIC's network (the NAD, e.g. a VM Network on a cluster-network/VLAN) cannot
  hand out an IP. This is a CLUSTER NETWORK config problem, not the VM manifest.
  Do NOT report the VM as "running" or "SSH ready" — it is not. Diagnose & report
  honestly: `kubectl get vmi <name> -n <ns> -o wide` (Scheduling, no IP),
  `kubectl describe pod -n <ns> virt-launcher-<name>-* | tail` (the multus error),
  and note the launcher pod retries forever (burns pod-network IPs). Tell the user:
  the VM is stuck on network "<nad>"; either (a) fix that VM network /
  cluster-network uplink in Hypervisor (Networks → Cluster/VM Networks — admin task),
  or (b) recreate the VM WITHOUT the bridge NIC (pod-network only) for an
  internal-IP VM. Offer to stop the stuck VM (`kubectl virt stop` / runStrategy
  Halted) to end the retry loop — disk is preserved.
- **Cannot verify right now (LLM rate limit / transient error mid-task)** — say
  exactly that: "couldn't verify the result yet (rate limited)". NEVER report
  status "from previous results" or from memory as if it were current — re-run the
  `kubectl get` when able, and only then state the real state.
- Empty result with rc=0 (only a header, no rows) — genuinely zero of that
  resource; say so plainly. (For VM images, never report 0 unless the command
  truly prints no data rows.)
