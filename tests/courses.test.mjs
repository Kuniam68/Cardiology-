import {test} from 'node:test';
import assert from 'node:assert/strict';
import {courses,getCourse,totalLessons} from '../assets/courses.js';
import {configured,currentUser,progress} from '../assets/auth.js';
test('course IDs and lesson IDs provide unique stable routes',()=>{
 const ids=new Set();let count=0;
 for(const c of courses){assert.match(c.id,/^[a-z-]+$/);assert.ok(!ids.has(c.id));ids.add(c.id);assert.equal(getCourse(c.id),c);const lessons=new Set();for(const l of c.lessons){assert.ok(!lessons.has(l.id));lessons.add(l.id);count++;assert.ok(l.body.length>500);assert.ok(Number.isInteger(l.answer));assert.ok(l.answer>=0&&l.answer<l.options.length);assert.ok(l.explanation.length>20)}assert.equal(c.minutes,c.lessons.reduce((n,l)=>n+l.minutes,0))}assert.equal(totalLessons,count);assert.equal(getCourse('missing-course'),undefined);
});
test('unconfigured accounts do not simulate authentication or enrollment',async()=>{if(configured)return;assert.equal(await currentUser(),null);assert.deepEqual(await progress(),{enrollments:[],lessons:[]})});
