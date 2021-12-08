locals {
  assume_role = length(var.k8s_assume_role_arn) > 0 ? true : false
}

data "aws_iam_policy_document" "external_dns" {
  count = local.k8s_irsa_role_create && !local.assume_role ? 1 : 0

  statement {
    sid = "ChangeResourceRecordSets"

    actions = [
      "route53:ChangeResourceRecordSets",
    ]

    resources = [for id in var.policy_allowed_zone_ids : "arn:aws:route53:::hostedzone/${id}"]

    effect = "Allow"
  }

  statement {
    sid = "ListResourceRecordSets"

    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]

    resources = [
      "*",
    ]

    effect = "Allow"
  }
}

data "aws_iam_policy_document" "external_dns_assume" {
  count = local.k8s_irsa_role_create && local.assume_role ? 1 : 0

  statement {
    sid = "AllowAssumeExternalDNSRole"

    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    resources = [
      var.k8s_assume_role_arn
    ]
  }
}

resource "aws_iam_policy" "external_dns" {
  count = local.k8s_irsa_role_create ? 1 : 0

  name        = "${var.k8s_irsa_role_name_prefix}-${var.helm_chart_name}"
  path        = "/"
  description = "Policy for external-dns service"

  policy = local.assume_role ? data.aws_iam_policy_document.external_dns_assume[0].json : data.aws_iam_policy_document.external_dns[0].json
}

data "aws_iam_policy_document" "external_dns_irsa" {
  count = local.k8s_irsa_role_create ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.cluster_identity_oidc_issuer_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_identity_oidc_issuer, "https://", "")}:sub"

      values = [
        "system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "external_dns" {
  count = local.k8s_irsa_role_create ? 1 : 0

  name               = "${var.k8s_irsa_role_name_prefix}-${var.helm_chart_name}"
  assume_role_policy = data.aws_iam_policy_document.external_dns_irsa[0].json
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  count = local.k8s_irsa_role_create ? 1 : 0

  role       = aws_iam_role.external_dns[0].name
  policy_arn = aws_iam_policy.external_dns[0].arn

}
