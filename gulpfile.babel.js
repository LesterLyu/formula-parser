import del from 'del';
import glob from 'glob';
import gulp from 'gulp';
import jison from 'gulp-jison';
import loadPlugins from 'gulp-load-plugins';
import path from 'path';
import webpack from 'webpack';
import webpackStream from 'webpack-stream';
import yargs from 'yargs';

import mochaGlobals from './test/setup/.globals';
import manifest from './package.json';

require('@babel/register');
require('@babel/core');

// Load all of our Gulp plugins
const $ = loadPlugins();

// Gather the library data from `package.json`
const config = manifest.babelBoilerplateOptions;
const mainFile = manifest.main;
const destinationFolder = path.dirname(mainFile);
const exportFileName = path.basename(mainFile, path.extname(mainFile));

function cleanDist() {
  return del([destinationFolder]);
}

function cleanTmp() {
  return del(['tmp']);
}

function onError() {
  $.util.beep();
}

// Generate parser
function generateParser() {
  return gulp.src('./src/grammar-parser/grammar-parser.jison')
    .pipe(jison({moduleType: 'commonjs'}))
    .pipe(gulp.dest('./src/grammar-parser'));
}

// Lint a set of files
function lint(files) {
  return gulp.src(files)
    .pipe($.plumber())
    .pipe($.eslint())
    .pipe($.eslint.format())
    .pipe($.eslint.failOnError())
    .on('error', onError);
}

function lintSrc() {
  return lint(['src/**/*.js', '!src/grammar-parser/grammar-parser.js']);
}

function lintTest() {
  return lint('test/**/*.js');
}

function lintGulpfile() {
  return lint('gulpfile.babel.js');
}

function build() {
  return gulp.src(path.join(config.entryFileName + '.js'))
    .pipe($.plumber())
    .pipe(webpackStream({
      mode: 'production',
      output: {
        filename: exportFileName + '.js',
        libraryTarget: 'umd',
        library: config.mainVarName
      },
      module: {
        rules: [
          {
            test: /\.js$/,
            exclude: /node_modules/,
            use: {
              loader: 'babel-loader',
            },
          }
        ],
      },
      devtool: 'source-map',
      target: 'node',
    }))
    .pipe(gulp.dest(destinationFolder))
    .pipe($.filter(['*', '!**/*.js.map']))
    .pipe($.rename(exportFileName + '.min.js'))
    .pipe($.sourcemaps.init({loadMaps: true}))
    .pipe($.uglify())
    .pipe($.sourcemaps.write('./'))
    .pipe(gulp.dest(destinationFolder));
}

function _mocha() {
  const envs = $.env.set({
    NODE_ENV: 'test'
  });

  return gulp.src(['test/setup/node.js', 'test/unit/**/*.js', 'test/integration/**/*.js'], {read: false})
    .pipe(envs)
    .pipe($.mocha({
      reporter: 'dot',
      globals: Object.keys(mochaGlobals.globals),
      ignoreLeaks: false,
      grep: yargs.argv.grep
    }));
}

function test() {
  return _mocha();
}

function coverage() {
  gulp.src(['src/**/*.js', '!src/grammar-parser/*'])
    .pipe($.istanbul.hookRequire())
    .on('finish', () => {
      return test()
        .pipe($.istanbul.writeReports())
    });
}

const watchFiles = ['src/**/*', 'test/**/*', 'package.json', '**/.eslintrc', '.jscsrc'];

// Run the headless tests as you make changes.
function watch() {
  gulp.watch(watchFiles, ['test']);
}

function testBrowser() {
  // Our testing bundle is made up of our tests, which
  // should individually load up pieces of our application.
  // We also include the browser setup file.
  const unitTestFiles = glob.sync('./test/unit/**/*.js');
  const integrationTestFiles = glob.sync('./test/integration/**/*.js');
  const allFiles = ['./test/setup/browser.js'].concat(unitTestFiles, integrationTestFiles);

  // Lets us differentiate between the first build and subsequent builds
  var firstBuild = true;

  // This empty stream might seem like a hack, but we need to specify all of our files through
  // the `entry` option of webpack. Otherwise, it ignores whatever file(s) are placed in here.
  return gulp.src('')
    .pipe($.plumber())
    .pipe(webpackStream({
      watch: true,
      entry: allFiles,
      output: {
        filename: '__spec-build.js'
      },
      module: {
        loaders: [
          // This is what allows us to author in future JavaScript
          {test: /\.js$/, exclude: /node_modules/, loader: 'babel-loader'},
          // This allows the test setup scripts to load `package.json`
          {test: /\.json$/, exclude: /node_modules/, loader: 'json-loader'}
        ]
      },
      plugins: [
        // By default, webpack does `n=>n` compilation with entry files. This concatenates
        // them into a single chunk.
        new webpack.optimize.LimitChunkCountPlugin({maxChunks: 1})
      ],
      devtool: 'inline-source-map'
    }, null, function () {
      if (firstBuild) {
        $.livereload.listen({port: 35729, host: 'localhost', start: true});
        var watcher = gulp.watch(watchFiles, ['lint']);
      } else {
        $.livereload.reload('./tmp/__spec-build.js');
      }
      firstBuild = false;
    }))
    .pipe(gulp.dest('./tmp'));
}

// Remove the built files
gulp.task('clean', cleanDist);

// Remove our temporary files
gulp.task('clean-tmp', cleanTmp);

// Lint our source code
gulp.task('lint-src', lintSrc);

// Lint our test code
gulp.task('lint-test', lintTest);

// Lint this file
gulp.task('lint-gulpfile', lintGulpfile);

// Lint everything
gulp.task('lint', (cb) => {
  gulp.series(lintSrc, lintTest, lintGulpfile);
  if (cb)
    cb();
});

// Build two versions of the library
gulp.task('build', (cb) => {
  gulp.task('lint')();
  gulp.task('clean')();
  build();
  cb();
});

// Build two versions of the library (without linting)
gulp.task('_build', build);

// Lint and run our tests
gulp.task('test', () => {
  gulp.task('lint')();
  return test()
});

// Set up coverage
gulp.task('coverage', coverage);

// Set up a livereload environment for our spec runner `test/runner.html`
gulp.task('test-browser', () => {
  gulp.task('lint')();
  gulp.task('clean-tmp')();
  testBrowser();
});

// Run the headless tests as you make changes
gulp.task('watch', watch);

// Generate parser
gulp.task('generate-parser', generateParser);

// An alias of test
gulp.task('default', () => {
  gulp.task('test')();
});
