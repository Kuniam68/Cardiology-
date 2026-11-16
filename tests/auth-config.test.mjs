import {test} from 'node:test';
import assert from 'node:assert/strict';
import {config} from '../assets/config.js';
import {configured,redirectUrl} from '../assets/auth.js';
test('Cardiobug uses the supplied public project configuration with optional CAPTCHA',()=>{assert.equal(configured,true);assert.equal(config.supabaseUrl,'https://zeneffylfgiyezpegqto.supabase.co');assert.match(config.supabasePublishableKey,/^sb_publishable_/);assert.equal(config.turnstileMode,'optional');assert.equal(config.googleSignIn,false)});
test('email callback destinations retain the GitHub Pages repository path',()=>{const old=globalThis.location;try{globalThis.location={href:'https://kuniam68.github.io/Cardiology-/forgot-password.html'};assert.equal(redirectUrl('signin.html'),'https://kuniam68.github.io/Cardiology-/signin.html');assert.equal(redirectUrl('reset-password.html'),'https://kuniam68.github.io/Cardiology-/reset-password.html')}finally{if(old===undefined)delete globalThis.location;else globalThis.location=old}});
