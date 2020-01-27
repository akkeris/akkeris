#!/usr/bin/env node
const assert = require('assert');
const fs = require('fs');
const yaml = require('/usr/local/lib/node_modules/js-yaml');

let files = process.argv.splice(2);
assert.ok(files.length > 0, 'No files were specified for translation!')

async function translate_cluster_issuer(issuer) {
	assert.ok(issuer.kind === "ClusterIssuer", 'Not a certificate object: ' + issuer.kind);
	assert.ok(issuer.apiVersion === "certmanager.k8s.io/v1alpha1", 'Certificate version was not valid: ' + issuer.apiVersion);
	issuer.apiVersion = "cert-manager.io/v1alpha2";
	if(issuer.spec.acme) {
		if(issuer.spec.acme.dns01) {
			let providers = JSON.parse(JSON.stringify(issuer.spec.acme.dns01.providers));
			issuer.spec.acme.solvers = await Promise.all(providers.map(async (provider) => {
				if(provider.name === "aws") {
					return {
						"dns01":{
							"route53":{
								"accessKeyID":provider.route53.accessKeyID,
								"region":provider.route53.region,
								"secretAccessKeySecretRef":provider.route53.secretAccessKeySecretRef,
							}
						}
					}
				} else {
					throw new Error("Unable to process unknown provider:" + provider.name);
				}
			}));
			delete issuer.spec.acme.dns01
		}
	}
	return yaml.safeDump(issuer, {lineWidth:1000});
}

async function translate_certificate(cert) {
	assert.ok(cert.kind === "Certificate", 'Not a certificate object: ' + cert.kind);
	assert.ok(cert.apiVersion === "certmanager.k8s.io/v1alpha1", 'Certificate version was not valid: ' + cert.apiVersion);
	cert.apiVersion = "cert-manager.io/v1alpha2";
	cert.spec.renewBefore = "360h";
	delete cert.spec.acme;
	return yaml.safeDump(cert, {lineWidth:1000});
}

async function translate_order(order) {
	assert.ok(order.kind === "Order", 'Not a order object: ' + order.kind);
	assert.ok(order.apiVersion === "certmanager.k8s.io/v1alpha1", 'Order version was not valid: ' + order.apiVersion);
	order.apiVersion = "acme.cert-manager.io/v1alpha2";
	delete order.spec.config;
	if(order.status.challenges) {
		let challenges = JSON.parse(JSON.stringify(order.status.challenges));
		delete order.status.challenges;
		order.status.authorizations = challenges.map((challenge) => {
			return {
				"url":challenge.authzURL,
				"identifier":challenge.dnsName,
				"wildcard":challenge.wildcard,
				"challenges":[
					{
						"url":challenge.url,
						"token":challenge.token,
						"type":challenge.type,
					}
				],
			}
		});
	}
	return yaml.safeDump(order, {lineWidth:1000});
}

async function translate_list(doc, file) {
	console.log('== translating items found in', file);
	return (await Promise.all(doc.items.map(async (item) => {
		if(item.kind === "Certificate") {
			return await translate_certificate(item);
		} else if(item.kind === "ClusterIssuer") {
			return await translate_cluster_issuer(item);
		} else if(item.kind === "Order") {
			return await translate_order(item);
		} else {
			throw new Error("Unable to determine type of " + item.kind);
		}
	}))).join('---\n');
}

function new_file(file) {
	return file + '-v1alpha2';
}

(async function() {
	await Promise.all( await files.map((async (file) => {
		const doc = yaml.safeLoad(fs.readFileSync(file, 'utf8'));
		if(doc.kind === "List" && doc.items) {
			let items = await translate_list(doc, file);
			fs.writeFileSync(new_file(file), items);
		} else if (doc.kind === "Certificate") {
			let item = await translate_certificate(doc);
			fs.writeFileSync(new_file(file), item);
		} else if (doc.kind === "ClusterIssuer") {
			let item = await translate_cluster_issuer(doc);
			fs.writeFileSync(new_file(file), item);
		} else if (doc.kind === "Order") {
			let item = await translate_order(doc);
			fs.writeFileSync(new_file(file), item);
		} else {
			throw new Error("Unable to process type " + doc.kind);
		}
	})));
})().catch((error) => console.log(error))