// Strumenti per la codifica Base64URL
function bufferToBase64url(buffer) {
    const bytes = new Uint8Array(buffer);
    let str = "";
    for (const charCode of bytes) {
        str += String.fromCharCode(charCode);
    }
    const base64String = btoa(str);
    return base64String.replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

function base64urlToBuffer(base64url) {
    const padding = "==".slice(0, (4 - (base64url.length % 4)) % 4);
    const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/") + padding;
    const str = atob(base64);
    const buffer = new ArrayBuffer(str.length);
    const byteView = new Uint8Array(buffer);
    for (let i = 0; i < str.length; i++) {
        byteView[i] = str.charCodeAt(i);
    }
    return buffer;
}

// Convert JSON object from server to WebAuthn configuration
function preformatMakeCredReq(makeCredReq) {
    makeCredReq.challenge = base64urlToBuffer(makeCredReq.challenge);
    makeCredReq.user.id = base64urlToBuffer(makeCredReq.user.id);

    if (makeCredReq.excludeCredentials) {
        for (let excludeCred of makeCredReq.excludeCredentials) {
            excludeCred.id = base64urlToBuffer(excludeCred.id);
        }
    }
    return makeCredReq;
}

function preformatGetAssertReq(getAssertReq) {
    getAssertReq.challenge = base64urlToBuffer(getAssertReq.challenge);

    if (getAssertReq.allowCredentials) {
        for (let allowCred of getAssertReq.allowCredentials) {
            allowCred.id = base64urlToBuffer(allowCred.id);
        }
    }
    return getAssertReq;
}

window.forgeFitWebAuthn = {
    isSupported: function() {
        return !!window.PublicKeyCredential;
    },

    register: async function(optionsJsonStr) {
        try {
            const options = JSON.parse(optionsJsonStr);
            const publicKeyCredentialCreationOptions = preformatMakeCredReq(options.publicKey);
            
            const credential = await navigator.credentials.create({
                publicKey: publicKeyCredentialCreationOptions
            });

            const response = {
                id: credential.id,
                rawId: bufferToBase64url(credential.rawId),
                type: credential.type,
                response: {
                    attestationObject: bufferToBase64url(credential.response.attestationObject),
                    clientDataJSON: bufferToBase64url(credential.response.clientDataJSON)
                }
            };
            return JSON.stringify(response);
        } catch (err) {
            console.error("WebAuthn Register Error:", err);
            throw err.message || err.toString();
        }
    },

    login: async function(optionsJsonStr) {
        try {
            const options = JSON.parse(optionsJsonStr);
            const publicKeyCredentialRequestOptions = preformatGetAssertReq(options.publicKey);

            const credential = await navigator.credentials.get({
                publicKey: publicKeyCredentialRequestOptions
            });

            const response = {
                id: credential.id,
                rawId: bufferToBase64url(credential.rawId),
                type: credential.type,
                response: {
                    authenticatorData: bufferToBase64url(credential.response.authenticatorData),
                    clientDataJSON: bufferToBase64url(credential.response.clientDataJSON),
                    signature: bufferToBase64url(credential.response.signature),
                    userHandle: credential.response.userHandle ? bufferToBase64url(credential.response.userHandle) : null
                }
            };
            return JSON.stringify(response);
        } catch (err) {
            console.error("WebAuthn Login Error:", err);
            throw err.message || err.toString();
        }
    }
};
