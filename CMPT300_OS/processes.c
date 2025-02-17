#include <stdio.h>
#include <sys/types.h>  /* for fork() and wait() */
#include <unistd.h>      /* for fork() and getpid() */
#include <sys/wait.h>    /* for wait() */
#include <stdlib.h>      /* for rand() and srand() */


int main()
{
	pid_t parentPID;
	pid_t childPID[10];
	pid_t grandChildPID[3];
	pid_t pid;
	int i;
	int j;
	int numChildren;
	int numGrandChildren;
	int seedParent;
	int seedChild;
	int status;


	printf("enter the seed for the parent process ");
	scanf("%d", &seedParent);
	srand(seedParent);
	numChildren = rand()%5 + 5;
	
	parentPID = getpid();
	printf("My process ID is %d\n", parentPID);
	
	for(i=0; i < numChildren; i++)
	{
		printf("%d is about to create a child\n", parentPID);
		
		pid = fork();

		if ( pid < 0 ) 
		{
			perror("fork");
			exit(EXIT_FAILURE);
		}
		else if ( pid == 0 )
		{
			childPID[i] = getpid();
			seedChild = seedParent + i;
			printf("I am a new child, " );
			printf("my process ID is %d, ", childPID[i]);
			printf("my seed is %d\n", seedChild);
			srand(seedChild);
			numGrandChildren = rand()%3 + 1;
			sleep(rand()%20+5);
			printf("I am child  %d ", childPID[i]);
			printf(" I will have %d children\n", numGrandChildren);
				
			for( j=0; j<numGrandChildren; j++)
			{
				printf("I am child %d ", childPID[i]);
				printf("I am about to create a child\n");
				pid = fork();
				if( pid == 0 ) 
				{
					grandChildPID[j] = getpid();
					printf("I am grandchild %d ", getpid());
                                	printf("My grandparent is %d ", parentPID);
					printf("My parent is %d\n",childPID[i]);
					sleep(rand()%10+5);
					printf("I am grandchild %d ", grandChildPID[j]);
					printf("with parent %d, ", childPID[i]);
					printf("I am about to terminate\n");
					exit(1);
				} 	
				else if( pid > 0 )
 				{
					grandChildPID[j] = pid;
					printf("I am child %d ", childPID[i]);
					printf("I just created a child %d \n", grandChildPID[j]);
				}
				else 
				{
					printf("I am child %d ", childPID[i]);
					printf("fork was unable to create my child\n");
				}

			}
			printf("I am child %d ", childPID[i]);
			printf(" I have had %d children\n", numGrandChildren);
			printf("I am waiting for my children to terminate\n");
			for( j=0; j<numGrandChildren; j++)
			{	
				pid = waitpid( grandChildPID[j], &status, 0);
				printf("I am child %d ", childPID[i]);
				printf("my child %d has been waited \n", grandChildPID[j]);
			}		
			printf(" I am child %d", childPID[i]);
			printf(" I am about to terminate %d\n", childPID[i]);
			sleep(5);
			exit(1);
		}
		else
		{
			childPID[i] = pid;
			printf("Parent %d has created a child with process ID %d\n", 
				parentPID, childPID[i] );
		}
	}
	for( j=0; j<numChildren; j++)
	{
		printf("I am the parent, I am waiting for child %d to terminate\n", childPID[j]);
		pid = waitpid( childPID[j], &status, 0);
		printf("I am process %d. My child %d is dead\n", parentPIe, childPID[j]);
	}
	printf("I am the parent, child %d has terminated", childPID[numChildren-1]);
	sleep(5);
	return 0;
}
			

