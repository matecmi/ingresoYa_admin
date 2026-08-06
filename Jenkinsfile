pipeline {

    agent {
        docker {
            image 'ghcr.io/cirruslabs/flutter:3.35.5'
        }
    }


    stages {


        stage('Version Flutter') {
            steps {
                sh '''
                flutter --version
                '''
            }
        }


        stage('Dependencies') {
            steps {
                sh '''
                flutter pub get
                '''
            }
        }


        stage('Analyze') {
            steps {
                sh '''
                flutter analyze
                '''
            }
        }


        stage('Tests') {
            steps {
                sh '''
                flutter test
                '''
            }
        }


        stage('Build Web') {
            steps {
                sh '''
                flutter build web --release
                '''
            }
        }


    }


    post {

        success {
            archiveArtifacts artifacts: 'build/web/**'
        }

    }

}