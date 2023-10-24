function(
  name='jsonnet-guestbook-ui',
  environment='test',
  namespace='apps'
)
  // {
  //   apiVersion: 'argoproj.io/v1alpha1',
  //   kind: 'Application',
  //   metadata: {
  //     name: 'argocd-playground',
  //     namespace: 'argocd',
  //     finalizers: [
  //       'resources-finalizer.argocd.argoproj.io',
  //     ],
  //   },
  //   spec: {
  //     destination: {
  //       namespace: 'helm-guestbook',
  //       server: {
  //         '[object Object]': null,
  //       },
  //     },
  //     project: 'default',
  //     source: {
  //       repoURL: 'https://github.com/argoproj/argocd-example-apps/',
  //       targetRevision: 'HEAD',
  //       path: name,
  //     },
  //   },
  // } +

  {


    apiVersion: 'argoproj.io/v1alpha1',
    kind: 'ApplicationSet',
    metadata: {
      name: name,
      namespace: 'argocd',
    },
    spec: {
      goTemplate: true,
      goTemplateOptions: ['missingkey=error'],
      generators: [
        {
          clusters: {
            selector: {
              matchLabels: {
                env: environment,
              },
            },
          },
        },
      ],
      template: {
        metadata: {
          name: '{{.name}}-' + name,
        },
        spec: {
          syncPolicy: {
            automated: {
              prune: true,
              selfHeal: true,
            },
            syncOptions: [
              'CreateNamespace=true',
            ],
          },
          project: 'default',
          source: {
            repoURL: 'https://github.com/avinashkris9/argocd-playground.git',
            targetRevision: 'HEAD',
            path: 'app-resources/' + name,
          },
          destination: {
            server: '{{.server}}',
            namespace: namespace,
          },
        },
      },
    },

  }
