import express from 'express';
import pg from 'pg';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import cookieParser from 'cookie-parser';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const {Pool}=pg;const pool=new Pool({connectionString:process.env.DATABASE_URL||process.env.GATEWAY_DATABASE_URL});
const app=express();const port=Number(process.env.PORT||8080);
const secret=process.env.JWT_SECRET;if(!secret||secret.length<32){console.error('JWT_SECRET must be at least 32 characters');process.exit(1)}
const accommodationUrl=process.env.ACCOMMODATION_URL||'http://127.0.0.1:8081',bookingUrl=process.env.BOOKING_URL||'http://127.0.0.1:8082',paymentUrl=process.env.PAYMENT_URL||'http://127.0.0.1:8083';
const { 'img-src': _defaultImgSrc, ...defaultCspDirectives } = helmet.contentSecurityPolicy.getDefaultDirectives();
app.disable('x-powered-by');
app.use(helmet({contentSecurityPolicy:{directives:{...defaultCspDirectives,imgSrc:["'self'",'data:','https://images.unsplash.com'],fontSrc:["'self'",'https://fonts.gstatic.com'],styleSrc:["'self'","'unsafe-inline'",'https://fonts.googleapis.com'],connectSrc:["'self'"]}}}));
app.use(express.json({limit:'20kb'}));
app.use(cookieParser());
const authLimiter=rateLimit({windowMs:15*60*1000,limit:10,standardHeaders:'draft-7',legacyHeaders:false});
const cookie={httpOnly:true,secure:process.env.COOKIE_SECURE==='true',sameSite:'strict',path:'/',maxAge:8*60*60*1000};
async function init(){await pool.query(`CREATE TABLE IF NOT EXISTS users(id BIGSERIAL PRIMARY KEY,name VARCHAR(80) NOT NULL,email VARCHAR(254) UNIQUE NOT NULL,password_hash TEXT NOT NULL,created_at TIMESTAMPTZ DEFAULT now())`)}
function auth(q,r,next){try{const t=q.cookies.holidays_session;if(!t)return r.status(401).json({error:'Please sign in to continue'});const p=jwt.verify(t,secret,{issuer:'holidays-app',audience:'holidays-web'});q.userId=Number(p.sub);if(!Number.isSafeInteger(q.userId))throw new Error('Invalid subject');next()}catch{return r.status(401).json({error:'Your session has expired. Please sign in again.'})}}
async function proxy(url,req,res,extra={}){try{const response=await fetch(url,{method:req.method,headers:{'content-type':'application/json',...extra},...(req.method==='GET'||req.method==='HEAD'?{}:{body:JSON.stringify(req.body||{})})});const body=await response.text();res.status(response.status).type(response.headers.get('content-type')||'application/json').send(body)}catch(e){console.error('Gateway upstream error:',e.message);res.status(503).json({error:'A Holidays service is temporarily unavailable'})}}
app.get('/api/health',async(_q,r)=>{try{await pool.query('SELECT 1');r.json({status:'ok',service:'holidays-api-gateway'})}catch{r.status(503).json({status:'error'})}});
app.post('/api/auth/register',authLimiter,async(q,r)=>{const name=String(q.body?.name||'').trim(),email=String(q.body?.email||'').trim().toLowerCase(),password=q.body?.password;if(name.length<2||name.length>80||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||typeof password!=='string'||password.length<10||password.length>72)return r.status(400).json({error:'Enter a valid name, email and password (10–72 characters)'});try{const hash=await bcrypt.hash(password,12);const {rows}=await pool.query('INSERT INTO users(name,email,password_hash) VALUES($1,$2,$3) RETURNING id,name,email',[name,email,hash]);const u=rows[0];r.cookie('holidays_session',jwt.sign({sub:String(u.id),email:u.email},secret,{expiresIn:'8h',issuer:'holidays-app',audience:'holidays-web'}),cookie);r.status(201).json({user:u})}catch(e){if(e.code==='23505')return r.status(409).json({error:'An account with this email already exists'});console.error(e);r.status(500).json({error:'Could not create account'})}});
app.post('/api/auth/login',authLimiter,async(q,r)=>{const email=String(q.body?.email||'').trim().toLowerCase(),password=q.body?.password;if(!email||typeof password!=='string')return r.status(400).json({error:'Enter email and password'});try{const {rows}=await pool.query('SELECT id,name,email,password_hash FROM users WHERE email=$1',[email]);const u=rows[0];if(!u||!(await bcrypt.compare(password,u.password_hash)))return r.status(401).json({error:'Email or password is incorrect'});r.cookie('holidays_session',jwt.sign({sub:String(u.id),email:u.email},secret,{expiresIn:'8h',issuer:'holidays-app',audience:'holidays-web'}),cookie);r.json({user:{id:u.id,name:u.name,email:u.email}})}catch(e){console.error(e);r.status(500).json({error:'Sign-in failed'})}});
app.post('/api/auth/logout',(_q,r)=>{r.clearCookie('holidays_session',{httpOnly:true,secure:process.env.COOKIE_SECURE==='true',sameSite:'strict',path:'/'});r.json({success:true})});
app.get('/api/auth/me',auth,async(q,r)=>{try{const {rows}=await pool.query('SELECT id,name,email FROM users WHERE id=$1',[q.userId]);if(!rows[0])return r.status(401).json({error:'Account no longer exists'});r.json({user:rows[0]})}catch(e){console.error(e);r.status(500).json({error:'Could not load account'})}});
app.get('/api/stays',(q,r)=>proxy(accommodationUrl+'/stays',q,r));
app.get('/api/bookings',auth,(q,r)=>proxy(bookingUrl+'/',q,r,{'x-user-id':String(q.userId)}));
app.post('/api/bookings',auth,(q,r)=>proxy(bookingUrl+'/',q,r,{'x-user-id':String(q.userId)}));
app.delete('/api/bookings/:reference',auth,(q,r)=>proxy(bookingUrl+'/'+encodeURIComponent(q.params.reference),q,r,{'x-user-id':String(q.userId)}));
app.post('/api/payments',auth,(q,r)=>proxy(paymentUrl+'/',q,r,{'x-user-id':String(q.userId)}));
app.get('/api/payments',auth,(q,r)=>proxy(paymentUrl+'/',q,r,{'x-user-id':String(q.userId)}));
const here=path.dirname(fileURLToPath(import.meta.url));const webRoot=path.resolve(here,'../../dist');app.use(express.static(webRoot));app.get('*',(q,r)=>r.sendFile(path.join(webRoot,'index.html')));
init().then(()=>app.listen(port,'0.0.0.0',()=>console.log('Holidays API Gateway listening on '+port))).catch(e=>{console.error('Gateway DB init failed',e);process.exit(1)});
